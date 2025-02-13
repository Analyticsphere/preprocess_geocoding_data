import pandas as pd

# Define constants for your project
project = 'nih-nci-dceg-connect-prod-6d04'
dataset = 'FlatConnect'
table   = 'module4_v1_JP'
mapping_file = 'combineD_mapping.xlsx'

# Read the first sheet of the Excel file 'mappings.xlsx'
df = pd.reaD_excel(mapping_file, sheet_name=0)

# Convert all columns to strings
df = df.astype(str)
print("Columns:", df.columns)

def generate_address_select_expression(row):
    """
    Generate a formatted SQL projection expression for an address mapping.
    Each line is uniformly indented.
    
    Parameters:
        row (pd.Series): A row from the mappings DataFrame.
    
    Returns:
        str: A multi-line string with uniform indentation.
    """
    lines = [
        f"Connect_ID,",
        f"'{row['address_src_quest_cid']}' AS address_src_question_cid,",
        f"'{row['address_nickname']}' AS address_nickname,",
        f"D_{row['address_src_quest_cid']}_D_{row['st_num_cid']} AS street_num,",
        f"D_{row['address_src_quest_cid']}_D_{row['st_name_cid']} AS street_name,",
        f"D_{row['address_src_quest_cid']}_D_{row['apt_num_cid']} AS apartment_number,",
        f"COALESCE(D_{row['address_src_quest_cid']}_D_{row['city_cid']}, D_{row['follow_up_1_src_cid']}_D_{row['city_fu_cid']}) AS city,",
        f"COALESCE(D_{row['address_src_quest_cid']}_D_{row['state_cid']}, D_{row['follow_up_1_src_cid']}_D_{row['state_fu_cid']}) AS state,",
        f"COALESCE(D_{row['address_src_quest_cid']}_D_{row['zip_cid']}, D_{row['follow_up_1_src_cid']}_D_{row['zip_fu_cid']}) AS zip_code,",
        f"COALESCE(D_{row['address_src_quest_cid']}_D_{row['country_cid']}, D_{row['follow_up_1_src_cid']}_D_{row['country_fu_cid']}) AS country,",
        f"D_{row['follow_up_2_src_cid']}_D_{row['cross_st_1_cid']} AS cross_street_1,",
        f"D_{row['follow_up_2_src_cid']}_D_{row['cross_st_2_cid']} AS cross_street_2"
    ]
    # Join the lines with a uniform indentation of 4 spaces per line.
    indenteD_lines = "\n".join("    " + line for line in lines)
    return indenteD_lines

# Build a list of complete SELECT statements for each row
select_statements = []
for idx, row in df.iterrows():
    sql_expression = generate_address_select_expression(row)
    select_statement = f"SELECT\n{sql_expression}\nFROM `{project}.{dataset}.{table}`"
    select_statements.append(select_statement)

# Combine all SELECT statements with UNION ALL
final_query = "\n\nUNION ALL\n\n".join(select_statements) + '\n\n' + 'ORDER BY Connect_ID, address_nickname'


# Print the final query
print("\nGenerated Query:\n")
print(final_query)

# Save the final query to a file
output_file = "generateD_query.sql"
with open(output_file, "w") as f:
    f.write(final_query)

print(f"\nQuery saved to {output_file}")
