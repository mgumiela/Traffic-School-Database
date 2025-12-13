
DROP TABLE IF EXISTS Platnosci CASCADE;
DROP TABLE IF EXISTS Przebieg_kursu CASCADE;
DROP TABLE IF EXISTS Kursant CASCADE;
DROP TABLE IF EXISTS Instruktorzy CASCADE;
DROP TABLE IF EXISTS Pojazd CASCADE;


DROP TYPE IF EXISTS rodzaj_skrzyni_enum CASCADE;
DROP TYPE IF EXISTS status_pojazdu_enum CASCADE;
DROP TYPE IF EXISTS status_pkk_enum CASCADE;
DROP TYPE IF EXISTS status_kursu_enum CASCADE;
DROP TYPE IF EXISTS metoda_platnosci_enum CASCADE;


-- 2. TWORZENIE STRUKTURY

-- Typy wyliczeniowe (ENUM)
CREATE TYPE rodzaj_skrzyni_enum AS ENUM ('Manualna', 'Automatyczna');
CREATE TYPE status_pojazdu_enum AS ENUM ('Sprawny', 'W serwisie', 'Sprzedany');
CREATE TYPE status_pkk_enum AS ENUM ('Aktywny', 'Zablokowany', 'Wykorzystany');
CREATE TYPE status_kursu_enum AS ENUM ('Rozpoczęty', 'W trakcie', 'Zakończony', 'Rezygnacja');
CREATE TYPE metoda_platnosci_enum AS ENUM ('Gotówka', 'Karta', 'Przelew');

-- Tabela POJAZD
CREATE TABLE Pojazd (
    ID_Pojazdu SERIAL PRIMARY KEY,
    model_pojazdu TEXT NOT NULL,
    numer_rejestracyjny VARCHAR(10) NOT NULL UNIQUE,
    numer_VIN VARCHAR(20),
    stan_techniczny TEXT,
    stan_paliwa INT,
    data_waznosci_ubezpieczen DATE,
    data_przegladu DATE,
    rodzaj_skrzyni_biegow rodzaj_skrzyni_enum NOT NULL,
    status_pojazdu status_pojazdu_enum DEFAULT 'Sprawny',
    przebieg INT
);

-- Tabela INSTRUKTORZY
CREATE TABLE Instruktorzy (
    ID_Instruktora SERIAL PRIMARY KEY,
    ID_pojazdu INT REFERENCES Pojazd(ID_Pojazdu),
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    adres VARCHAR(64),
    numer_telefonu VARCHAR(20),
    email VARCHAR(255),
    data_waznosci_licencji DATE
);

-- Tabela KURSANT
CREATE TABLE Kursant (
    ID_Kursanta SERIAL PRIMARY KEY,
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    PESEL VARCHAR(11) UNIQUE,
    adres VARCHAR(64),
    numer_telefonu VARCHAR(20),
    email VARCHAR(255),
    data_urodzenia DATE,
    zgoda_marketingowa BOOLEAN DEFAULT FALSE,
    numer_PKK VARCHAR(20),
    data_wydania_PKK DATE,
    status_PKK status_pkk_enum DEFAULT 'Aktywny',
    badania_lekarskie BOOLEAN DEFAULT FALSE,
    data_waznosci_badan DATE,
    imie_op VARCHAR(50),
    nazwisko_op VARCHAR(50),
    numer_telefonu_op VARCHAR(20)
);

-- Tabela PRZEBIEG_KURSU
CREATE TABLE Przebieg_kursu (
    ID_indywidualnego_kursu SERIAL PRIMARY KEY,
    ID_Kursanta INT NOT NULL REFERENCES Kursant(ID_Kursanta),
    ID_Instruktora INT REFERENCES Instruktorzy(ID_Instruktora),
    czy_oplacone BOOLEAN DEFAULT FALSE,
    status_kursu status_kursu_enum DEFAULT 'Rozpoczęty',
    data_zapisu DATE DEFAULT CURRENT_DATE,
    suma_godzin_teorii INT DEFAULT 0,
    suma_godzin_praktyki INT DEFAULT 0,
    czy_zdany_wew_teoria BOOLEAN DEFAULT FALSE,
    czy_zdany_wew_praktyka BOOLEAN DEFAULT FALSE,
    czy_zdany_zew_teoria BOOLEAN DEFAULT FALSE,
    czy_zdany_zew_praktyka BOOLEAN DEFAULT FALSE
);

-- Tabela PLATNOSCI
CREATE TABLE Platnosci (
    ID_Platnosci SERIAL PRIMARY KEY,
    ID_indywidualnego_kursu INT NOT NULL REFERENCES Przebieg_kursu(ID_indywidualnego_kursu),
    kwota DECIMAL(10, 2) NOT NULL,
    data_platnosci DATE DEFAULT CURRENT_DATE,
    metoda_platnosci metoda_platnosci_enum,
    tytul_platnosci TEXT,
    ID_faktury VARCHAR(50)
);
