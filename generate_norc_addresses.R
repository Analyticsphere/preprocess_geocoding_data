library(readxl)
library(dplyr)
library(glue)
library(writexl)

# Define constants for your project
project <- 'nih-nci-dceg-connect-prod-6d04'
dataset <- 'FlatConnect'
table   <- 'module4_v1_JP'
mapping_file <- 'address_concept_map.xlsx'

# Read the mapping file (first sheet) and convert all columns to character
df <- read_excel(mapping_file, sheet = 1) %>%
  mutate(across(everything(), as.character))
print("Columns:")
print(names(df))

# Function to generate the SQL SELECT expression for a given row.
generate_address_select_expression <- function(row) {
  lines <- c(
    "Connect_ID,",
    glue("'{row[['address_src_quest_cid']]}' AS address_src_question_cid,"),
    glue("'{row[['address_nickname']]}' AS address_nickname,"),
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['st_num_cid']]} AS street_num,"),
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['st_name_cid']]} AS street_name,"),
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['apt_num_cid']]} AS apartment_number,"),
    glue("COALESCE(D_{row[['address_src_quest_cid']]}_D_{row[['city_cid']]}, D_{row[['follow_up_1_src_cid']]}_D_{row[['city_fu_cid']]}) AS city,"),
    glue("COALESCE(D_{row[['address_src_quest_cid']]}_D_{row[['state_cid']]}, D_{row[['follow_up_1_src_cid']]}_D_{row[['state_fu_cid']]}) AS state,"),
    glue("COALESCE(D_{row[['address_src_quest_cid']]}_D_{row[['zip_cid']]}, D_{row[['follow_up_1_src_cid']]}_D_{row[['zip_fu_cid']]}) AS zip_code,"),
    glue("COALESCE(D_{row[['address_src_quest_cid']]}_D_{row[['country_cid']]}, D_{row[['follow_up_1_src_cid']]}_D_{row[['country_fu_cid']]}) AS country,"),
    glue("D_{row[['follow_up_2_src_cid']]}_D_{row[['cross_st_1_cid']]} AS cross_street_1,"),
    glue("D_{row[['follow_up_2_src_cid']]}_D_{row[['cross_st_2_cid']]} AS cross_street_2")
  )
  # Indent each line with 4 spaces
  indented_lines <- paste0("    ", lines, collapse = "\n")
  return(indented_lines)
}

# Build a list of complete SELECT statements for each row
select_statements <- apply(df, 1, function(r) {
  sql_expr <- generate_address_select_expression(r)
  glue("SELECT\n{sql_expr}\nFROM `{project}.{dataset}.{table}`")
})

# Combine all SELECT statements with UNION ALL
union_query <- paste(select_statements, collapse = "\n\nUNION ALL\n\n")

# User Profile Physical Address sub query
user_profile_sub_query <-
"    SELECT
        Connect_ID,
        '332759827' AS address_src_question_cid,
        'user_profile_physical_address' AS address_nickname,
        CONCAT(d_207908218, ' ', d_224392018) AS street_num, -- concatenate address line 1 and address line 2
        NULL AS street_name, -- there is no street_name for the user profile address since it is given in the string_num field
        NULL AS apartment_number, -- there is no appartment_number for the user profile address since it is given in the string_num field
        d_451993790 AS city,
        d_187799450 AS state,
        d_449168732 AS zip_code,
        NULL AS country, -- there is no country field provided in the user profile
        NULL AS cross_street_1,
        NULL AS cross_street_2
    FROM `nih-nci-dceg-connect-prod-6d04.FlatConnect.participants_JP`
    WHERE
        Connect_ID IS NOT NULL
        -- Ensure that at least one of these fields has non-empty values
        AND (
            (d_207908218 IS NOT NULL AND d_207908218 != '') OR
            (d_224392018 IS NOT NULL AND d_224392018 != '') OR
            (d_451993790 IS NOT NULL AND d_451993790 != '') OR
            (d_187799450 IS NOT NULL AND d_187799450 != '') OR
            (d_449168732 IS NOT NULL AND d_449168732 != '')
    )"

# Helper function to indent text by a given indent string (default is 4 spaces)
indent_text <- function(text, indent = "    ") {
  # Split text by newline into individual lines
  lines <- unlist(strsplit(text, "\n"))
  # Prepend each line with the indent
  indented_lines <- paste0(indent, lines)
  # Reassemble into one string with newlines
  paste(indented_lines, collapse = "\n")
}

# Indent the union query using helper function
indented_union_query <- indent_text(union_query)

# # Indent the user profile sub query using helper function
# user_profile_sub_query <- indent_text(user_profile_sub_query)

# Use glue to build the final query with preserved indentation
final_query <- glue("
SELECT *
FROM (

{indented_union_query}

UNION ALL

{user_profile_sub_query}

) t
WHERE COALESCE(street_num, street_name, apartment_number, city, state, zip_code, country, cross_street_1, cross_street_2) IS NOT NULL
ORDER BY Connect_ID, address_nickname
", .trim = FALSE)

# Display the final query in the console
cat(final_query, "\n")

# Save the final query to a file
writeLines(final_query, "address_query.sql")
