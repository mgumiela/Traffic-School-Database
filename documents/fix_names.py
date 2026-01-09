import re
import random

FILE_PATH = r'C:\Users\Maciej\Desktop\Studia\bazy_danych\GITHUB_TSD\Traffic-School-Database\documents\data.sql'

FIRST_NAMES = ["Anna", "Maria", "Katarzyna", "Małgorzata", "Agnieszka", "Krystyna", "Barbara", "Ewa", "Elżbieta", "Zofia", "Jan", "Andrzej", "Piotr", "Krzysztof", "Stanisław", "Tomasz", "Paweł", "Józef", "Marcin", "Marek", "Michał", "Grzegorz", "Jerzy", "Tadeusz", "Adam", "Łukasz", "Zbigniew", "Ryszard", "Dariusz", "Henryk"]
LAST_NAMES = ["Nowak", "Kowalski", "Wiśniewski", "Wójcik", "Kowalczyk", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski", "Kozłowski", "Jankowski", "Mazur", "Wojciechowski", "Kwiatkowski", "Krawczyk", "Kaczmarek", "Piotrowski", "Grabowski", "Zając", "Pawłowski", "Michalski", "Król", "Wieczorek", "Jabłoński", "Wróbel", "Nowakowski", "Majewski", "Olszewski"]

def generate_name():
    return f"'{random.choice(FIRST_NAMES)}'", f"'{random.choice(LAST_NAMES)}'"

def fix_names():
    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # The format in data.sql for Opiekun inserts is:
    # insert into Opiekun (ID_Kursanta, imie_op, nazwisko_op, numer_telefonu_op) values (..., 'Nieznany', 'Nieznany', ...);
    
    # We will use regex substitution with a lambda function to generate unique names for each match
    
    def replace_match(match):
        # match.group(0) is the whole string being replaced
        # match.group(1) is the ID part
        # match.group(2) are the trailing parts
        
        # We look for 'Nieznany', 'Nieznany' pattern specifically
        
        f_name, l_name = generate_name()
        return f"{match.group(1)}{f_name}, {l_name}{match.group(2)}"

    # Regex to capture the context around 'Nieznany', 'Nieznany'
    # Adjust regex to match the exact spacing/quoting in the file
    # Pattern: (values \(\d+, )'Nieznany', 'Nieznany'(.+?\);)
    pattern = re.compile(r"(values \(\d+, )'Nieznany', 'Nieznany'(.+?\);)", re.IGNORECASE)
    
    if not pattern.search(content):
        # Try simplified if exact matching fails (maybe spacing differs)
        pattern = re.compile(r"(values\s*\(\s*\d+\s*,\s*)'Nieznany'\s*,\s*'Nieznany'(.+?;)", re.IGNORECASE)

    new_content = pattern.sub(replace_match, content)
    
    if content == new_content:
        print("No changes made. Check regex.")
        return

    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Successfully updated Guardian names.")

if __name__ == "__main__":
    fix_names()
