import re
import datetime
import collections

DATA_FILE = r'C:\Users\Maciej\Desktop\Studia\bazy_danych\GITHUB_TSD\Traffic-School-Database\documents\data_fixed_logic.sql'
CURRENT_DATE = datetime.date(2026, 1, 9)

def parse_date(date_str):
    try:
        return datetime.datetime.strptime(date_str.strip("'"), '%Y-%m-%d').date()
    except ValueError:
        return None

def parse_bool(bool_str):
    return bool_str.lower() == 'true'

def parse_val(val):
    val = val.strip()
    if val.upper() == 'NULL': return None
    if val.startswith("'") and val.endswith("'"): return val.strip("'")
    if val.lower() in ('true', 'false'): return parse_bool(val)
    try:
        if '.' in val: return float(val)
        return int(val)
    except:
        return val

def load_data():
    tables = {
        'Pojazd': [],
        'Instruktorzy': [],
        'Kursant': [],
        'Opiekun': [],
        'Przebieg_kursu': [],
        'Platnosci': [],
        'Opinie': []
    }
    
    current_table = None
    with open(DATA_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip().lower().startswith('insert into'):
                match = re.search(r'insert into (\w+)', line, re.IGNORECASE)
                if match:
                    table_name = match.group(1)
                    if table_name in tables:
                        values_match = re.search(r'values \((.*)\);', line, re.IGNORECASE)
                        if values_match:
                            val_str = values_match.group(1)
                            vals = [parse_val(v) for v in re.split(r",(?=(?:[^']*'[^']*')*[^']*$)", val_str)]
                            tables[table_name].append(vals)
    return tables

def verify_data(tables):
    errors = []
    warnings = []

    pojazdy = {i+1: row for i, row in enumerate(tables['Pojazd'])}
    instruktorzy = {i+1: row for i, row in enumerate(tables['Instruktorzy'])}
    kursanci = {i+1: row for i, row in enumerate(tables['Kursant'])}
    przebieg = {i+1: row for i, row in enumerate(tables['Przebieg_kursu'])} # ID_indywidualnego_kursu
    
    # 1. Verify Triggers Logic
    
    # tr_auto_koniec: zew_praktyka=True => status='Zakończony'
    for pid, row in przebieg.items():
        # Indices: 10=zew_praktyka, 3=status
        zew_p = row[10]
        status = row[3]
        if zew_p and status != 'Zakończony':
            errors.append(f"Przebieg ID {pid}: Passed external practice but status is '{status}' (expected 'Zakończony').")

    # tr_tylko_sprawne_auta: Instruktor assigned to 'Sprawny' car
    for iid, row in instruktorzy.items():
        vid = row[0] # ID_pojazdu
        if vid in pojazdy:
            car_status = pojazdy[vid][8] # status_pojazdu (index 8)
            if car_status != 'Sprawny':
                errors.append(f"Instruktor ID {iid}: Assigned to car ID {vid} with status '{car_status}' (must be 'Sprawny').")
        else:
             errors.append(f"Instruktor ID {iid}: Assigned to non-existent car ID {vid}.")

    # tr_wymog_30h: wew_praktyka=True => godz_p >= 30
    for pid, row in przebieg.items():
        wew_p = row[8] # wew_praktyka
        godz_p = row[6] # godz_praktyki
        if wew_p and godz_p < 30:
            errors.append(f"Przebieg ID {pid}: Passed internal practice with only {godz_p} hours (min 30 required).")

    # tr_sprawdz_badania
    for pid, row in przebieg.items():
        kid = row[0] # ID_Kursanta
        if kid in kursanci:
            waznosc_badan_str = kursanci[kid][12] # data_waznosci_badan
            if waznosc_badan_str:
                waznosc = parse_date(waznosc_badan_str)
                data_zapisu_str = row[4]
                data_zapisu = parse_date(data_zapisu_str)
                
                if waznosc and data_zapisu and waznosc < data_zapisu:
                     errors.append(f"Przebieg ID {pid}: Kursant ID {kid} had expired exams ({waznosc}) at enrollment ({data_zapisu}).")

    # tr_licencja_instruktora
    for pid, row in przebieg.items():
        iid = row[1] # ID_Instruktora
        if iid in instruktorzy:
            licencja_str = instruktorzy[iid][6] 
            if licencja_str:
                licencja = parse_date(licencja_str)
                data_zapisu_str = row[4]
                data_zapisu = parse_date(data_zapisu_str)
                if licencja and data_zapisu and licencja < data_zapisu:
                    errors.append(f"Przebieg ID {pid}: Instruktor ID {iid} had expired license ({licencja}) at enrollment ({data_zapisu}).")

    # tr_auto_oplata: Sum payments >= 3200 => Oplacone=True
    kurs_payments = {}
    for row in tables['Platnosci']:
        kid = row[0] # ID_indywidualnego_kursu
        kwota = row[1]
        kurs_payments[kid] = kurs_payments.get(kid, 0) + kwota
        
    for pid, row in przebieg.items():
        oplacone = row[2] # czy_oplacone
        total_paid = kurs_payments.get(pid, 0)
        if total_paid >= 3200 and not oplacone:
            errors.append(f"Przebieg ID {pid}: Fully paid ({total_paid}) but status is not 'opłacone'.")
        if total_paid < 3200 and oplacone:
             warnings.append(f"Przebieg ID {pid}: Marked as paid but only collected {total_paid} (Target 3200).")

    # 2. Business Rules
    
    # Opiekun for < 18 only
    student_ages = {}
    for kid, row in kursanci.items():
        dob_str = row[2] # data_urodzenia
        dob = parse_date(dob_str)
        if dob:
            age = (CURRENT_DATE - dob).days / 365.25
            student_ages[kid] = age
            
    for row in tables['Opiekun']:
        kid = row[0] # ID_Kursanta
        if kid in student_ages:
            if student_ages[kid] >= 18:
                 errors.append(f"Opiekun assigned to adult student ID {kid} (Age: {student_ages[kid]:.1f}).")
        else:
            errors.append(f"Opiekun assigned to non-existent student ID {kid}.")
            
    students_with_guardians = set(row[0] for row in tables['Opiekun'])
    for kid, age in student_ages.items():
        if age < 18 and kid not in students_with_guardians:
            errors.append(f"Underage student ID {kid} (Age: {age:.1f}) missing Guardian.")

    return errors, warnings

if __name__ == "__main__":
    tables = load_data()
    errors, warnings = verify_data(tables)
    
    print(f"Analyzed {len(tables['Kursant'])} students, {len(tables['Przebieg_kursu'])} courses.")
    
    error_counts = collections.Counter()
    for e in errors:
        if "Passed external practice" in e: key = "Status mismatch (passed ext -> Zakończony)"
        elif "Assigned to car" in e: key = "Car status mismatch"
        elif "Passed internal practice" in e: key = "Practice hours mismatch (<30h)"
        elif "expired exams" in e: key = "Expired medical exams"
        elif "expired license" in e: key = "Expired instructor license"
        elif "Fully paid" in e: key = "Payment status mismatch (Paid but status false)"
        elif "Guardian assigned to adult" in e: key = "Guardian on adult"
        elif "missing Guardian" in e: key = "Underage missing guardian"
        else: key = "Other"
        error_counts[key] += 1
        
    if errors:
        print("\nERRORS SUMMARY:")
        for k, v in error_counts.items():
            print(f"{k}: {v}")
            
        print("\nFIRST 10 ERRORS:")
        for e in errors[:10]:
            print(f"- {e}")
    else:
        print("\nNO ERRORS FOUND.")

    warning_counts = collections.Counter()
    for w in warnings:
        if "Marked as paid" in w: key = "Payment mismatch (Status true but amount < 3200)"
        else: key = "Other"
        warning_counts[key] += 1
        
    if warnings:
        print("\nWARNINGS SUMMARY:")
        for k, v in warning_counts.items():
            print(f"{k}: {v}")
            
        print("\nFIRST 10 WARNINGS:")
        for w in warnings[:10]:
            print(f"- {w}")
