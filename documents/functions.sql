CREATE OR REPLACE FUNCTION saldo_kursanta(id_kursu INT) 
RETURNS DECIMAL(10,2) AS '
DECLARE
    cena_kursu DECIMAL(10,2) := 3200.00;
    suma_wplat DECIMAL(10,2);
BEGIN
    -- Sumujemy wszystkie wpłaty dla danego kursu
    SELECT COALESCE(SUM(kwota), 0) INTO suma_wplat 
    FROM Platnosci 
    WHERE ID_indywidualnego_kursu = id_kursu;

    -- Zwracamy to co zostało do zapłaty
    RETURN cena_kursu - suma_wplat;
END;
' LANGUAGE 'plpgsql';

-- Przykład użycia: SELECT saldo_kursanta(1);



CREATE OR REPLACE FUNCTION dni_do_przegladu(id_auta INT) RETURNS INT AS '
DECLARE
    data_przegladu DATE;
    wynik INT;
BEGIN
    -- Pobieramy datę przeglądu
    SELECT Pojazd.data_przegladu INTO data_przegladu 
    FROM Pojazd 
    WHERE ID_Pojazdu = id_auta;

    wynik := data_przegladu - CURRENT_DATE;

    -- Jeśli termin minął, zwracamy 0
    IF wynik < 0 THEN 
        RETURN 0; 
    END IF;

    RETURN wynik;
END;
' LANGUAGE 'plpgsql';

-- Użycie: SELECT model_pojazdu, numer_rejestracyjny, dni_do_przegladu(ID_Pojazdu) FROM Pojazd;