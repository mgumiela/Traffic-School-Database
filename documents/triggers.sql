CREATE FUNCTION auto_zakonczenie_kursu() RETURNS TRIGGER AS '
BEGIN
    -- Jeśli zdano praktykę zewnętrzną, zmieniamy status na Zakończony
    IF NEW.czy_zdany_zew_praktyka = TRUE THEN
        NEW.status_kursu := ''Zakończony''; 
    END IF;
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_auto_koniec
BEFORE INSERT OR UPDATE ON Przebieg_kursu
FOR EACH ROW
EXECUTE PROCEDURE auto_zakonczenie_kursu();



CREATE OR REPLACE FUNCTION sprawdz_stan_auta() RETURNS TRIGGER AS '
DECLARE
    stan_auta status_pojazdu_enum;
BEGIN
    -- Pobieramy status auta
    SELECT status_pojazdu INTO stan_auta FROM Pojazd WHERE ID_Pojazdu = NEW.ID_pojazdu;
    
    -- Jeśli auto nie jest sprawne, zwraca błąd
    IF stan_auta <> ''Sprawny'' THEN
        RAISE EXCEPTION ''Błąd: Nie można przypisać tego auta. Jego status to: %'', stan_auta;
    END IF;
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_tylko_sprawne_auta
BEFORE INSERT OR UPDATE ON Instruktorzy
FOR EACH ROW
EXECUTE PROCEDURE sprawdz_stan_auta();



CREATE OR REPLACE FUNCTION wymagane_godziny() RETURNS TRIGGER AS '
BEGIN
    -- Jeśli zaliczamy egzamin, a godzin jest za mało
    IF NEW.czy_zdany_wew_praktyka = TRUE AND NEW.suma_godzin_praktyki < 30 THEN
        RAISE EXCEPTION ''Błąd: Nie można zaliczyć egzaminu! Kursant wyjeździł tylko % godzin (wymagane 30).'', NEW.suma_godzin_praktyki;
    END IF;
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_wymog_30h
BEFORE UPDATE ON Przebieg_kursu
FOR EACH ROW
EXECUTE PROCEDURE wymagane_godziny();



CREATE OR REPLACE FUNCTION sprawdz_badania_przed_kursem() RETURNS TRIGGER AS '
DECLARE
    waznosc DATE;
BEGIN
    SELECT data_waznosci_badan INTO waznosc FROM Kursant WHERE ID_Kursanta = NEW.ID_Kursanta;

    IF waznosc < CURRENT_DATE THEN
        RAISE EXCEPTION ''Błąd: Kursant ma nieważne badania lekarskie! Ważność skończyła się: %'', waznosc;
    END IF;
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_sprawdz_badania
BEFORE INSERT ON Przebieg_kursu
FOR EACH ROW
EXECUTE PROCEDURE sprawdz_badania_przed_kursem();