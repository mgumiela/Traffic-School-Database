import re
import datetime
import random

FILE_PATH = r'C:\Users\Maciej\Desktop\Studia\bazy_danych\GITHUB_TSD\Traffic-School-Database\documents\data.sql'
OUTPUT_PATH = r'C:\Users\Maciej\Desktop\Studia\bazy_danych\GITHUB_TSD\Traffic-School-Database\documents\data_fixed_logic.sql'

def parse_val(val):
    val = val.strip()
    if val.upper() == 'NULL': return None
    if val.startswith("'") and val.endswith("'"): return val.strip("'")
    if val.lower() == 'true': return True
    if val.lower() == 'false': return False
    try:
        return float(val) # Use float for numbers to handle decimals easily
    except:
        return val

def format_val(val):
    if val is None: return 'null'
    if isinstance(val, bool): return 'true' if val else 'false'
    if isinstance(val, str): return f"'{val}'"
    return str(val)

def fix_data():
    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.splitlines()
    new_lines = []
    
    # Store data for logic
    przebieg_indices = {} # ID -> line_index
    przebieg_data = {} # ID -> parsed_values_list
    platnosci_data = [] # List of (line_index, parsed_values_list)
    
    # regexes
    insert_przebieg = re.compile(r"insert into Przebieg_kursu .*? values \((.*)\);", re.IGNORECASE)
    insert_platnosci = re.compile(r"insert into Platnosci .*? values \((.*)\);", re.IGNORECASE)
    
    # Pass 1: Parse Key Tables
    course_id_counter = 0 # Assume sequential
    
    # Actually, Przebieg_kursu uses SERIAL PK, so insert order defines ID.
    # Platnosci references ID_indywidualnego_kursu.
    
    current_course_id = 0
    
    for i, line in enumerate(lines):
        if insert_przebieg.search(line):
            current_course_id += 1
            match = insert_przebieg.search(line)
            val_str = match.group(1)
            # basic CSV parse
            vals = [parse_val(v) for v in re.split(r",(?=(?:[^']*'[^']*')*[^']*$)", val_str)]
            
            # Przebieg cols index (based on schema/data inspection):
            # ID_Kursanta(0), ID_Instruktora(1), czy_oplacone(2), status_kursu(3), data_zapisu(4), 
            # sum_t(5), sum_p(6), wew_t(7), wew_p(8), zew_t(9), zew_p(10)
            
            # Note: insert statement in data.sql might allow nullable fields? 
            # "values (1, 10, false, 'Rozpoczęty', '2025-12-10', 13, 20, true, true, true, true);"
            # Looks strictly ordered matching schema.
            
            przebieg_indices[current_course_id] = i
            przebieg_data[current_course_id] = vals
            
        elif insert_platnosci.search(line):
            match = insert_platnosci.search(line)
            val_str = match.group(1)
            vals = [parse_val(v) for v in re.split(r",(?=(?:[^']*'[^']*')*[^']*$)", val_str)]
            # Platnosci cols: ID_indywidualnego_kursu(0), kwota(1), ...
            platnosci_data.append( (i, vals) )
            
    # Calculate Payment Totals
    course_payments = {} # ID -> sum
    for idx, vals in platnosci_data:
        cid = int(vals[0])
        amount = float(vals[1])
        course_payments[cid] = course_payments.get(cid, 0) + amount
        
    # Logic Fixes
    
    # 1. Przebieg Rules
    for cid, vals in przebieg_data.items():
        # vals is list of values
        
        updated = False
        
        # Cols
        oplacone = vals[2]
        status = vals[3]
        sum_p = vals[6]
        wew_p = vals[8]
        zew_p = vals[10]
        
        # Rule: zew_p=True => status='Zakończony'
        if zew_p == True and status != 'Zakończony':
            vals[3] = 'Zakończony'
            updated = True
            
        # Rule: wew_p=True => sum_p >= 30
        if wew_p == True and (isinstance(sum_p, (int, float)) and sum_p < 30):
            vals[6] = 30
            updated = True
            
        # Rule: Payment Consistency
        # We need to decide intent.
        # If 'oplacone' is True => We MUST have >= 3200 payments.
        # If 'oplacone' is False => We check sum. If sum >= 3200, set oplacone=True.
        
        total_paid = course_payments.get(cid, 0)
        
        if oplacone == True:
            if total_paid < 3200:
                # We need to ADD a payment. We can't easily insert a new line in the middle of list iteration w/o messing up indices?
                # Actually we can just append a new payment insert at the end of the file or after the comments.
                # Or better: We modifying the data set. We can append new payment lines to a list to be added at the end of file.
                pass # handled in Pass 2
        elif oplacone == False:
            if total_paid >= 3200:
                vals[2] = True
                updated = True
                
        if updated:
            # Reconstruct CSV string
            new_val_str = ", ".join(format_val(v) for v in vals)
            # Reconstruct Line
            # We assume "insert into Przebieg_kursu ... values (...);" format
            # We need to preserve the columns part?
            # original line: insert into Przebieg_kursu (ID_Kursanta, ...) values (...);
            # We can replace the values part.
            
            orig_line = lines[przebieg_indices[cid]]
            new_line = re.sub(r"values \(.*\);", f"values ({new_val_str});", orig_line, flags=re.IGNORECASE)
            lines[przebieg_indices[cid]] = new_line

    # 2. Payment Adjustments
    new_payment_lines = []
    
    # Determine the highest invoice ID for uniqueness (simple heuristic)
    # id_faktury format: 'FV/2025/94373'
    
    for cid, vals in przebieg_data.items():
        oplacone = vals[2] # Current state (possibly updated above if sum was high)
        total_paid = course_payments.get(cid, 0)
        
        if oplacone == True and total_paid < 3200:
            diff = 3200 - total_paid
            # Create a supplementary payment
            # Columns: ID_indywidualnego_kursu, kwota, data_platnosci, metoda_platnosci, tytul_platnosci, id_faktury
            # We need date equal to enrollment or later.
            # Just use '2026-01-09' or vals[4] (data_zapisu)
            date = vals[4]
            # ID_Faktury random
            fv = f"'FV/2026/FIX{cid}'"
            
            payment_line = f"insert into Platnosci (ID_indywidualnego_kursu, kwota, data_platnosci, metoda_platnosci, tytul_platnosci, id_faktury) values ({cid}, {diff:.2f}, {format_val(date)}, 'Przelew', 'Dopłata wyrównawcza', {fv});"
            new_payment_lines.append(payment_line)
            
    # Write Output
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')
            
        if new_payment_lines:
            f.write("\n-- Korekta płatności (Generated corrections)\n")
            for line in new_payment_lines:
                f.write(line + '\n')

    print("Fix script completed.")

if __name__ == "__main__":
    fix_data()
