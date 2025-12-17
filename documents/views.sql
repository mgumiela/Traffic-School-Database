-- =============================================
-- 1. Widok: Postępy Kursantów (Raport ogólny)
-- Cel: Szybki podgląd, na jakim etapie jest każdy kursant i kto go szkoli.
-- =============================================
CREATE OR REPLACE VIEW v_postepy_kursantow AS
SELECT 
    k.imie || ' ' || k.nazwisko AS kursant,
    k.numer_pkk,
    i.imie || ' ' || i.nazwisko AS instruktor,
    pk.status_kursu,
    pk.suma_godzin_teorii,
    pk.suma_godzin_praktyki,
    CASE 
        WHEN pk.suma_godzin_praktyki >= 30 THEN 'Zakończona'
        ELSE (30 - pk.suma_godzin_praktyki) || ' h do wyjeżdżenia'
    END AS status_praktyki,
    pk.czy_zdany_wew_teoria AS egz_wew_teoria,
    pk.czy_zdany_wew_praktyka AS egz_wew_praktyka,
    pk.czy_zdany_zew_praktyka AS egz_panstwowy
FROM Przebieg_kursu pk
JOIN Kursant k ON pk.ID_Kursanta = k.ID_Kursanta
LEFT JOIN Instruktorzy i ON pk.ID_Instruktora = i.ID_Instruktora
ORDER BY pk.data_zapisu DESC;

-- =============================================
-- 2. Widok: Flota i Przeglądy (Dla serwisu)
-- Cel: Wykaz aut, którym kończy się przegląd lub ubezpieczenie (np. w ciągu 30 dni)
--      lub które są obecnie w serwisie.
-- =============================================
CREATE OR REPLACE VIEW v_pojazdy_do_serwisu AS
SELECT 
    model_pojazdu,
    numer_rejestracyjny,
    status_pojazdu,
    przebieg,
    data_przegladu,
    data_waznosci_ubezpieczen,
    CASE 
        WHEN data_przegladu < CURRENT_DATE THEN 'PRZEGLĄD PRZETERMINOWANY!'
        WHEN data_przegladu BETWEEN CURRENT_DATE AND (CURRENT_DATE + 30) THEN 'Przegląd wkrótce'
        WHEN data_waznosci_ubezpieczen < CURRENT_DATE THEN 'BRAK UBEZPIECZENIA!'
        WHEN data_waznosci_ubezpieczen BETWEEN CURRENT_DATE AND (CURRENT_DATE + 30) THEN 'Ubezpieczenie wkrótce'
        ELSE 'OK'
    END AS uwaga_serwisowa
FROM Pojazd
WHERE status_pojazdu = 'W serwisie'
   OR data_przegladu < (CURRENT_DATE + 30)
   OR data_waznosci_ubezpieczen < (CURRENT_DATE + 30);

-- =============================================
-- 3. Widok: Finanse i Zaległości
-- Cel: Lista kursantów, którzy nie opłacili jeszcze kursu w całości (status != Zakończony/Rezygnacja).
-- =============================================
CREATE OR REPLACE VIEW v_zaleglosci_platnicze AS
SELECT 
    k.imie || ' ' || k.nazwisko AS kursant,
    k.numer_telefonu,
    pk.data_zapisu,
    pk.status_kursu,
    COALESCE(SUM(p.kwota), 0) AS wplacona_kwota
FROM Przebieg_kursu pk
JOIN Kursant k ON pk.ID_Kursanta = k.ID_Kursanta
LEFT JOIN Platnosci p ON pk.ID_indywidualnego_kursu = p.ID_indywidualnego_kursu
WHERE pk.czy_oplacone = FALSE 
  AND pk.status_kursu IN ('Rozpoczęty', 'W trakcie')
GROUP BY k.ID_Kursanta, pk.ID_indywidualnego_kursu, k.imie, k.nazwisko, k.numer_telefonu, pk.data_zapisu, pk.status_kursu;