import json
import os

def clean_extensions(input_file_path, output_file_path):
    # Load the internal messy JSON file
    with open(input_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    # Extract only the clean extension unique IDs
    recommendations = []
    for item in data:
        if isinstance(item, dict) and "identifier" in item and "id" in item["identifier"]:
            recommendations.append(item["identifier"]["id"])
            
    # Wrap it inside the standardized VS Code workspace template
    output_data = {
        "recommendations": recommendations
    }
    
    # Ensure target directory exists
    os.makedirs(os.path.dirname(output_file_path), exist_ok=True)
    
    # Save the polished file
    with open(output_file_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=4)
        
    print(f"Success! Created a portable workspace file with {len(recommendations)} extensions.")

# Execution variables (Change paths if running elsewhere)
# Automatically finds the folder where this script is saved
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Combines that folder path with your file names
input_path = os.path.join(SCRIPT_DIR, "extensions.json")
output_path = os.path.join(SCRIPT_DIR, "extensions2.json")

clean_extensions(input_path, output_path)

clean_extensions(input_path, output_path)
