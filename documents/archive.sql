-- Implementacja archiwizacji danych poprzez przeniesienie danych to tabel "tabela_archiwum"

BEGIN;

-- Tabele archiwalne to mirror minus klucze obce, wymóg unique i plus data archiwizacji

-- KURSANT ARCHIWUM
CREATE TABLE IF NOT EXISTS Kursant_Archiwum (
    ID_Archiwum SERIAL PRIMARY KEY,
    oryginalne_ID_Kursanta INT,
    imie VARCHAR(50),
    nazwisko VARCHAR(50),
    PESEL VARCHAR(11),
    adres VARCHAR(64),
    numer_telefonu VARCHAR(20),
    email VARCHAR(255),
    data_urodzenia DATE,
    zgoda_marketingowa BOOLEAN,
    numer_PKK VARCHAR(20),
    data_wydania_PKK DATE,
    status_PKK status_pkk_enum,
    badania_lekarskie BOOLEAN,
    data_waznosci_badan DATE,
    data_archiwizacji TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- OPIEKUN ARCHIWUM
CREATE TABLE IF NOT EXISTS Opiekun_Archiwum (
    ID_Archiwum SERIAL PRIMARY KEY,
    oryginalne_ID_Opiekuna INT,
    oryginalne_ID_Kursanta INT,
    imie_op VARCHAR(50),
    nazwisko_op VARCHAR(50),
    numer_telefonu_op VARCHAR(20),
    email_op VARCHAR(255),
    data_archiwizacji TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PRZEBIEG_KURSU ARCHIWUM
CREATE TABLE IF NOT EXISTS Przebieg_kursu_Archiwum (
    ID_Archiwum SERIAL PRIMARY KEY,
    oryginalne_ID_kursu INT,
    oryginalne_ID_Kursanta INT,
    oryginalne_ID_Instruktora INT,
    czy_oplacone BOOLEAN,
    status_kursu status_kursu_enum,
    data_zapisu DATE,
    suma_godzin_teorii INT,
    suma_godzin_praktyki INT,
    czy_zdany_wew_teoria BOOLEAN,
    czy_zdany_wew_praktyka BOOLEAN,
    czy_zdany_zew_teoria BOOLEAN,
    czy_zdany_zew_praktyka BOOLEAN,
    data_archiwizacji TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1.4 PLATNOSCI ARCHIWUM
CREATE TABLE IF NOT EXISTS Platnosci_Archiwum (
    ID_Archiwum SERIAL PRIMARY KEY,
    oryginalne_ID_Platnosci INT,
    oryginalne_ID_kursu INT,
    kwota DECIMAL(10, 2),
    data_platnosci DATE,
    metoda_platnosci metoda_platnosci_enum,
    tytul_platnosci TEXT,
    ID_faktury VARCHAR(50),
    data_archiwizacji TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMIT;

-- Funkcja archiwizacji jako parametr - ile miesięcy musi minąć od zapisu/końca kursu aby uznać go za archiwalny
CREATE OR REPLACE FUNCTION archiwizuj_stare_dane(miesiecy_wstecz INT) 
RETURNS TEXT AS $$
DECLARE
    limit_daty DATE;
    liczba_kursow INT;
    liczba_platnosci INT;
    liczba_kursantow INT;
BEGIN
    -- Ustalenie daty granicznej
    limit_daty := CURRENT_DATE - (miesiecy_wstecz || ' months')::INTERVAL;

    -- Identifikacja kursów do archiwizacji
    -- Kryterium: Status Zakończony/Rezygnacja ORAZ data_zapisu starsza niż limit

    -- Tabela tymczasowa z ID Kursów
    CREATE TEMP TABLE temp_kursy_do_archiwum ON COMMIT DROP AS
    SELECT ID_indywidualnego_kursu, ID_Kursanta
    FROM Przebieg_kursu
    WHERE status_kursu IN ('Zakończony', 'Rezygnacja')
      AND data_zapisu < limit_daty;

    -- Kopiowanie i Usuwanie PŁATNOŚCI
    -- Kopia
    INSERT INTO Platnosci_Archiwum (
        oryginalne_ID_Platnosci, oryginalne_ID_kursu, kwota, data_platnosci, 
        metoda_platnosci, tytul_platnosci, ID_faktury
    )
    SELECT 
        p.ID_Platnosci, p.ID_indywidualnego_kursu, p.kwota, p.data_platnosci, 
        p.metoda_platnosci, p.tytul_platnosci, p.ID_faktury
    FROM Platnosci p
    JOIN temp_kursy_do_archiwum t ON p.ID_indywidualnego_kursu = t.ID_indywidualnego_kursu;

    GET DIAGNOSTICS liczba_platnosci = ROW_COUNT;

    -- Usunięcie
    DELETE FROM Platnosci 
    WHERE ID_indywidualnego_kursu IN (SELECT ID_indywidualnego_kursu FROM temp_kursy_do_archiwum);

    -- Kopiowanie i Usuwanie PRZEBIEGU KURSU
    -- Kopia
    INSERT INTO Przebieg_kursu_Archiwum (
        oryginalne_ID_kursu, oryginalne_ID_Kursanta, oryginalne_ID_Instruktora, 
        czy_oplacone, status_kursu, data_zapisu, suma_godzin_teorii, 
        suma_godzin_praktyki, czy_zdany_wew_teoria, czy_zdany_wew_praktyka, 
        czy_zdany_zew_teoria, czy_zdany_zew_praktyka
    )
    SELECT 
        pk.ID_indywidualnego_kursu, pk.ID_Kursanta, pk.ID_Instruktora, 
        pk.czy_oplacone, pk.status_kursu, pk.data_zapisu, pk.suma_godzin_teorii, 
        pk.suma_godzin_praktyki, pk.czy_zdany_wew_teoria, pk.czy_zdany_wew_praktyka, 
        pk.czy_zdany_zew_teoria, pk.czy_zdany_zew_praktyka
    FROM Przebieg_kursu pk
    JOIN temp_kursy_do_archiwum t ON pk.ID_indywidualnego_kursu = t.ID_indywidualnego_kursu;

    GET DIAGNOSTICS liczba_kursow = ROW_COUNT;

    -- Usunięcie
    DELETE FROM Przebieg_kursu 
    WHERE ID_indywidualnego_kursu IN (SELECT ID_indywidualnego_kursu FROM temp_kursy_do_archiwum);

    -- Kopiowanie i Usuwanie KURSANTÓW (Oraz Opiekunów)
    -- Kryterium: Archiwizujemy kursanta TYLKO JEŚLI nie ma już żadnych aktywnych kursów w tabeli Przebieg_kursu
    
    -- Kursanci, którzy byli w tabeli tymczasowej, ale nie mają już żadnych wpisów w przebiegu kursu
    CREATE TEMP TABLE temp_kursanci_do_archiwum ON COMMIT DROP AS
    SELECT DISTINCT t.ID_Kursanta
    FROM temp_kursy_do_archiwum t
    WHERE NOT EXISTS (
        SELECT 1 FROM Przebieg_kursu pk_active 
        WHERE pk_active.ID_Kursanta = t.ID_Kursanta
    );

    -- Archiwizacja Opiekuna
    INSERT INTO Opiekun_Archiwum (
        oryginalne_ID_Opiekuna, oryginalne_ID_Kursanta, imie_op, nazwisko_op, 
        numer_telefonu_op, email_op
    )
    SELECT 
        o.ID_Opiekuna, o.ID_Kursanta, o.imie_op, o.nazwisko_op, 
        o.numer_telefonu_op, o.email_op
    FROM Opiekun o
    JOIN temp_kursanci_do_archiwum tk ON o.ID_Kursanta = tk.ID_Kursanta;

    DELETE FROM Opiekun 
    WHERE ID_Kursanta IN (SELECT ID_Kursanta FROM temp_kursanci_do_archiwum);

    -- Kopia KURSANTÓW do archiwum
    INSERT INTO Kursant_Archiwum (
        oryginalne_ID_Kursanta, imie, nazwisko, PESEL, adres, numer_telefonu, 
        email, data_urodzenia, zgoda_marketingowa, numer_PKK, data_wydania_PKK, 
        status_PKK, badania_lekarskie, data_waznosci_badan
    )
    SELECT 
        k.ID_Kursanta, k.imie, k.nazwisko, k.PESEL, k.adres, k.numer_telefonu, 
        k.email, k.data_urodzenia, k.zgoda_marketingowa, k.numer_PKK, k.data_wydania_PKK, 
        k.status_PKK, k.badania_lekarskie, k.data_waznosci_badan
    FROM Kursant k
    JOIN temp_kursanci_do_archiwum tk ON k.ID_Kursanta = tk.ID_Kursanta;

    GET DIAGNOSTICS liczba_kursantow = ROW_COUNT;

    -- Usunięcie kursantów
    DELETE FROM Kursant 
    WHERE ID_Kursanta IN (SELECT ID_Kursanta FROM temp_kursanci_do_archiwum);

    RETURN 'Archiwizacja zakończona. Przeniesiono: ' || 
           liczba_platnosci || ' płatności, ' || 
           liczba_kursow || ' kursów, ' || 
           liczba_kursantow || ' kursantów.';
END;
$$ LANGUAGE plpgsql;