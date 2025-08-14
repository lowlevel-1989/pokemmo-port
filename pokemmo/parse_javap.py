# unzip PokeMMO.exe "f/*" "com/badlogic/gdx/controllers/desktop/*"
# javap -v "${$(grep -rli --binary-files=text "client.ui.login.username" f/*.class | head -n 1)%.class}"

import re


def extract_jamepad_fields(javap_output):
    results = {}

    # Extraer clase completa
    class_match = re.search(r'this_class: #\d+\s+// ([\w/]+)', javap_output)
    if class_match:
        full_class = class_match.group(1)
        results["class_name"] = full_class.split("/")[-1]
        results["package"] = ".".join(full_class.split("/")[:-1])
    else:
        results["class_name"] = "Unknown"
        results["package"] = "Unknown"

    # Extraer clase base (super_class)
    super_class_match = re.search(r'super_class: #\d+\s+// ([\w/]+)', javap_output)
    if super_class_match:
        results["extends"] = super_class_match.group(1).split("/")[-1]
    else:
        results["extends"] = "Unknown"

    # Extraer tipo del argumento del método addListener
    add_listener_match = re.search(r'public void addListener\(([^)]+)\);', javap_output)
    if add_listener_match:
        arg_type_raw = add_listener_match.group(1)
        arg_type = arg_type_raw.split("/")[-1].replace(";", "")  # e.g. f/ke0 -> ke0
        results["listener_type"] = arg_type.replace("f.", "")
    else:
        results["listener_type"] = "Unknown"

    return results

def credentials_extract_fields(javap_output):
    results = {}

    # Extract the class name (last part after /)
    class_match = re.search(r'this_class: #\d+\s+// ([\w/]+)', javap_output)
    class_name = class_match.group(1).split('/')[-1] if class_match else "Unknown"

    # Pattern to match static fields and their annotation keys
    field_pattern = re.compile(
        r"""
        public\s+static\s+(?:java\.lang\.String|boolean)\s+(\w+);   # field name
        .*?
        key\s*=\s*"client\.ui\.login\.(\w+)"                        # annotation key
        """,
        re.DOTALL | re.VERBOSE
    )

    # Find all matching field + key pairs
    for match in field_pattern.finditer(javap_output):
        value = match.group(1)
        key = match.group(2)
        results[key] = value

    results["class_name"] = class_name
    return results


# Read the output from file
with open("credentials.javap.txt", "r") as f:
    javap_text = f.read()

field = credentials_extract_fields(javap_text)

print(field)

print("class   ", field.get("class_name"))
print("username", field.get("username"))
print("password", field.get("password"))
print("auto    ", field.get("auto"))

with open("patch_template/credentials.java", "r") as f:
    credentials_template = f.read()

try:
    credentials_patch = credentials_template.format(**field)
    with open("src/auto/{class_name}.java".format(**field), "w") as f:
        f.write(credentials_patch)
except:
    pass

with open("jamepad.javap.txt", "r") as f:
    jamepad_text = f.read()

field = extract_jamepad_fields(jamepad_text)
print(field)

print("Class name:      ", field.get("class_name"))
print("Package:         ", field.get("package"))
print("Extends:         ", field.get("extends"))
print("Listener type:   ", field.get("listener_type"))

with open("patch_template/jamepad.java", "r") as f:
    jamepad_template = f.read()

try:
    jamepad_patch = jamepad_template.format(**field)
    with open("src/auto/{class_name}.java".format(**field), "w") as f:
        f.write(jamepad_patch)
except:
    pass

