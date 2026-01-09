CREATE ROLE administrator;
CREATE ROLE pracownik_biura;
CREATE ROLE instruktor;

-- Uprawnienia dla administratora (wszystko)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO administrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO administrator;

-- Uprawnienia dla Biura (zarządzanie bazą danych)
GRANT SELECT, INSERT, UPDATE ON Kursant, Przebieg_kursu, Platnosci, Pojazd, Instruktorzy TO pracownik_biura;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO pracownik_biura;


-- Uprawnienia dla Instruktora (tylko wgląd w kursantów i edycja godzin)
GRANT SELECT ON Kursant, Pojazd TO instruktor;
GRANT SELECT, UPDATE (suma_godzin_teorii, suma_godzin_praktyki, czy_zdany_wew_teoria, czy_zdany_wew_praktyka) ON Przebieg_kursu TO instruktor;