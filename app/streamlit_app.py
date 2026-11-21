
from pathlib import Path

import pandas as pd
import streamlit as st

# Seitenkonfiguration
st.set_page_config(
    page_title="Supply Chain Analytics",
    page_icon="📦",
    layout="wide",
)

# Dateipfad
PROJEKTVERZEICHNIS = Path(__file__).resolve().parent.parent
EXCEL_DATEI = PROJEKTVERZEICHNIS / "reports" / "supply_chain_report.xlsx"


# Excel-Daten laden
@st.cache_data
def lade_daten(dateipfad, aenderungszeit):
    return pd.read_excel(
        dateipfad,
        sheet_name=[
            "Prognosen",
            "Modellvergleich",
            "Bestandskennzahlen",
            "Servicelevel-Szenarien",
        ],
        engine="openpyxl",
    )


# Haupttitel
st.title("Supply Chain Demand Forecasting & Inventory Optimization")

st.markdown(
    "Interaktives Dashboard zur Analyse von Absatzprognosen, "
    "Modellleistung und Bestandskennzahlen."
)

# Datenverfügbarkeit prüfen
if not EXCEL_DATEI.exists():
    st.error("Die Excel-Datei wurde nicht gefunden.")
    st.stop()

try:
    daten = lade_daten(
        str(EXCEL_DATEI),
        EXCEL_DATEI.stat().st_mtime,
    )
except Exception as fehler:
    st.error(f"Fehler beim Laden der Excel-Daten: {fehler}")
    st.stop()


# Datenqualität prüfen
try:
    prognosen_pruefung = daten["Prognosen"]
    modelle_pruefung = daten["Modellvergleich"]
    bestand_pruefung = daten["Bestandskennzahlen"]
    szenarien_pruefung = daten["Servicelevel-Szenarien"]

    # Erwartete Datenstruktur überprüfen
    assert len(prognosen_pruefung) == 93, (
        "Die Testperiode muss 93 Tage enthalten."
    )

    assert len(modelle_pruefung) == 2, (
        "Es werden zwei Prognosemodelle erwartet."
    )

    assert len(bestand_pruefung) == 7, (
        "Es werden sieben Bestandskennzahlen erwartet."
    )

    assert len(szenarien_pruefung) == 3, (
        "Es werden drei Servicelevel-Szenarien erwartet."
    )

    # Erforderliche Spalten überprüfen
    erforderliche_spalten = {
        "Datum",
        "Ist-Absatz",
        "Seasonal Naive",
        "Gradient Boosting",
    }

    assert erforderliche_spalten.issubset(
        prognosen_pruefung.columns
    ), "Erforderliche Prognosespalten fehlen."

    # Fehlende Werte in den wichtigsten Spalten überprüfen
    assert not prognosen_pruefung[
        list(erforderliche_spalten)
    ].isna().any().any(), (
        "Die Prognosedaten enthalten fehlende Werte."
    )

except AssertionError as fehler:
    st.error(f"Datenvalidierung fehlgeschlagen: {fehler}")
    st.stop()

# Dashboard-Navigation
tab_prognosen, tab_modelle, tab_bestand = st.tabs(
    ["📈 Prognosen", "📊 Modellleistung", "📦 Bestandsmanagement"]
)


# --------------------------------------------------
# 1. Absatzprognosen
# --------------------------------------------------
with tab_prognosen:
    st.subheader("Absatzprognosen im Zeitverlauf")

    prognosen = daten["Prognosen"].copy()

    # Datumsspalte vorbereiten
    prognosen["Datum"] = pd.to_datetime(prognosen["Datum"])
    prognosen = prognosen.sort_values("Datum")

    startdatum = prognosen["Datum"].min().date()
    enddatum = prognosen["Datum"].max().date()

    # Zeitraum auswählen
    zeitraum = st.date_input(
        "Analysezeitraum auswählen",
        value=(startdatum, enddatum),
        min_value=startdatum,
        max_value=enddatum,
    )

    if len(zeitraum) == 2:
        von, bis = zeitraum

        gefiltert = prognosen[
            (prognosen["Datum"].dt.date >= von)
            & (prognosen["Datum"].dt.date <= bis)
        ]

        # Zeitreihenvergleich
        diagrammdaten = gefiltert.set_index("Datum")[
            ["Ist-Absatz", "Seasonal Naive", "Gradient Boosting"]
        ]

        st.line_chart(diagrammdaten)

        st.caption(
            "Täglicher Absatzvergleich innerhalb der 93-tägigen "
            "Testperiode. Die Prognosen stammen aus der "
            "bestehenden Modellevaluierung."
        )
    else:
        st.info("Bitte einen Start- und Endtermin auswählen.")


# --------------------------------------------------
# 2. Modellleistung
# --------------------------------------------------
with tab_modelle:
    st.subheader("Prognosegenauigkeit")

    modellvergleich = daten["Modellvergleich"].copy()

    # MAE-Werte aus der Excel-Tabelle lesen
    mae_naive = float(modellvergleich.iloc[0]["MAE"])
    mae_gb = float(modellvergleich.iloc[1]["MAE"])

    verbesserung = (mae_naive - mae_gb) / mae_naive * 100

    spalte1, spalte2, spalte3 = st.columns(3)

    with spalte1:
        st.metric(
            "MAE – Gradient Boosting",
            f"{mae_gb:,.2f}",
        )

    with spalte2:
        st.metric(
            "MAE – Seasonal Naive",
            f"{mae_naive:,.2f}",
        )

    with spalte3:
        st.metric(
            "MAE-Verbesserung",
            f"{verbesserung:.1f} %",
        )

    st.caption(
        "Die Kennzahlen beziehen sich auf die 93-tägige "
        "Testperiode vom 20.02.2016 bis zum 22.05.2016."
    )


# --------------------------------------------------
# 3. Bestandsmanagement
# --------------------------------------------------
with tab_bestand:
    st.subheader("Bestandskennzahlen")

    bestandsdaten = daten["Bestandskennzahlen"].copy()

    # Kennzahlen aus der Excel-Tabelle lesen
    durchschnittlicher_absatz = float(bestandsdaten.iloc[2, 1])
    sicherheitsbestand = float(bestandsdaten.iloc[5, 1])
    meldebestand = float(bestandsdaten.iloc[6, 1])

    spalte1, spalte2, spalte3 = st.columns(3)

    with spalte1:
        st.metric(
            "Durchschnittlicher Tagesabsatz",
            f"{durchschnittlicher_absatz:,.0f}",
        )

    with spalte2:
        st.metric(
            "Sicherheitsbestand",
            f"{sicherheitsbestand:,.0f}",
        )

    with spalte3:
        st.metric(
            "Meldebestand",
            f"{meldebestand:,.0f}",
        )

    st.caption(
        "Die Bestandskennzahlen basieren auf aggregierten "
        "Absatzdaten und simulierten Annahmen "
        "(Lieferzeit: 7 Tage, Zielservicelevel: 95 %). "
        "Es handelt sich nicht um tatsächlich beobachtete Lagerbestände."
    )

    st.divider()

    # Servicelevel-Szenarien
    st.subheader("Servicelevel-Szenarien")

    szenarien = daten["Servicelevel-Szenarien"].copy()

    for spalte in ["Sicherheitsbestand", "Meldebestand"]:
        szenarien[spalte] = pd.to_numeric(
            szenarien[spalte],
            errors="raise",
        )

    szenarien["Servicelevel"] = (
        szenarien["Servicelevel"].astype(str).str.strip()
    )

    st.markdown("**Sicherheitsbestand nach Zielservicelevel**")

    diagrammdaten = szenarien.set_index("Servicelevel")[
        ["Sicherheitsbestand"]
    ]

    st.bar_chart(diagrammdaten)

    # Interaktive Szenarioauswahl
    auswahl = st.selectbox(
        "Zielservicelevel auswählen",
        options=szenarien["Servicelevel"].tolist(),
        index=1,
    )

    gewaehltes_szenario = szenarien.loc[
        szenarien["Servicelevel"] == auswahl
    ].iloc[0]

    spalte1, spalte2 = st.columns(2)

    with spalte1:
        st.metric(
            "Sicherheitsbestand",
            f"{gewaehltes_szenario['Sicherheitsbestand']:,.0f}",
        )

    with spalte2:
        st.metric(
            "Meldebestand",
            f"{gewaehltes_szenario['Meldebestand']:,.0f}",
        )

    st.caption(
        "Die Servicelevel sind simulierte Zielwerte und wurden "
        "nicht empirisch überprüft. Ein höheres Zielservicelevel "
        "führt unter den Modellannahmen zu einem höheren "
        "Sicherheitsbestand."
    )
