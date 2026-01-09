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



CREATE OR REPLACE FUNCTION sprawdz_licencje_instruktora() RETURNS TRIGGER AS '
DECLARE
    waznosc_licencji DATE;
BEGIN
    -- Pobieramy datę ważności licencji przypisanego instruktora
    SELECT data_waznosci_licencji INTO waznosc_licencji FROM Instruktorzy WHERE ID_Instruktora = NEW.ID_Instruktora;

    -- Jeśli licencja wygasła, blokujemy przypisanie
    IF waznosc_licencji < CURRENT_DATE THEN
        RAISE EXCEPTION ''Błąd: Instruktor ma nieważną licencję (ważna do: %). Wybierz innego instruktora.'', waznosc_licencji;
    END IF;
    
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_licencja_instruktora
BEFORE INSERT OR UPDATE ON Przebieg_kursu
FOR EACH ROW
EXECUTE PROCEDURE sprawdz_licencje_instruktora();



CREATE OR REPLACE FUNCTION aktualizuj_czy_oplacone() RETURNS TRIGGER AS '
DECLARE
    suma_wplat DECIMAL(10, 2);
    cena_kursu DECIMAL(10, 2) := 3200.00; 
BEGIN
    -- Liczymy sumę wszystkich wpłat dla danego kursu
    SELECT SUM(kwota) INTO suma_wplat 
    FROM Platnosci 
    WHERE ID_indywidualnego_kursu = NEW.ID_indywidualnego_kursu;

    -- Jeśli suma wpłat pokrywa cenę, odhaczamy kurs jako opłacony
    IF suma_wplat >= cena_kursu THEN
        UPDATE Przebieg_kursu 
        SET czy_oplacone = TRUE 
        WHERE ID_indywidualnego_kursu = NEW.ID_indywidualnego_kursu;
    END IF;

    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER tr_auto_oplata
AFTER INSERT OR UPDATE ON Platnosci
FOR EACH ROW
EXECUTE PROCEDURE aktualizuj_czy_oplacone();
