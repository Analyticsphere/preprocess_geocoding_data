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
    "CURRENT_TIMESTAMP() AS address_delivered_ts,",
    glue("'{row[['address_src_quest_cid']]}' AS address_src_question_cid,"),
    glue("'{row[['address_nickname']]}' AS address_nickname,"),
    "NULL AS address_line_1,",
    "NULL AS address_line_2,",
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['st_num_cid']]} AS street_num,"),
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['st_name_cid']]} AS street_name,"),
    glue("D_{row[['address_src_quest_cid']]}_D_{row[['apt_num_cid']]} AS apartment_num,"),
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
"-- Get User Profile Physical Address
SELECT
    Connect_ID,
    CURRENT_TIMESTAMP() AS address_delivered_ts,
    '207908218' AS address_src_question_cid,
    'user_profile_physical_address' AS address_nickname,
    d_207908218 AS address_line_1,
    d_224392018 AS address_line_2,
    NULL AS street_num,       -- there is no street_num for the user profile address since it is given in the address_line_1[2] fields
    NULL AS street_name,      -- there is no street_name for the user profile address since it is given in the address_line_1[2] fields
    NULL AS apartment_num, -- there is no appartment_num for the user profile address since it is given in the address_line_1[2] fields
    d_451993790 AS city,
    d_187799450 AS state,
    d_449168732 AS zip_code,
    NULL AS country, -- there is no country field provided in the user profile
    NULL AS cross_street_1,
    NULL AS cross_street_2
FROM `nih-nci-dceg-connect-prod-6d04.FlatConnect.participants_JP`
WHERE
    Connect_ID IS NOT NULL
    AND (
        (d_207908218 IS NOT NULL AND d_207908218 != '') OR
        (d_224392018 IS NOT NULL AND d_224392018 != '') OR
        (d_451993790 IS NOT NULL AND d_451993790 != '') OR
        (d_187799450 IS NOT NULL AND d_187799450 != '') OR
        (d_449168732 IS NOT NULL AND d_449168732 != '')
    )

UNION ALL

-- Get User Profile Mailing Address if Physical Address is Missing
SELECT
    Connect_ID,
    CURRENT_TIMESTAMP() AS address_delivered_ts,
    '521824358' AS address_src_question_cid,
    'user_profile_mailing_address' AS address_nickname,
    d_521824358 AS address_line_1,
    d_442166669 AS address_line_2,
    NULL AS street_num,       -- there is no street_num for the user profile address since it is given in the address_line_1[2] fields
    NULL AS street_name,      -- there is no street_name for the user profile address since it is given in the address_line_1[2] fields
    NULL AS apartment_num, -- there is no appartment_num for the user profile address since it is given in the address_line_1[2] fields
    d_703385619 AS city,
    d_634434746 AS state,
    d_892050548 AS zip_code,
    NULL AS country, -- there is no country field provided in the user profile
    NULL AS cross_street_1,
    NULL AS cross_street_2
FROM `nih-nci-dceg-connect-prod-6d04.FlatConnect.participants_JP`
WHERE
    Connect_ID IS NOT NULL
    AND (
        (d_207908218 IS NULL OR d_207908218 = '') AND
        (d_224392018 IS NULL OR d_224392018 = '') AND
        (d_451993790 IS NULL OR d_451993790 = '') AND
        (d_187799450 IS NULL OR d_187799450 = '') AND
        (d_449168732 IS NULL OR d_449168732 = '')
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
user_profile_sub_query <- indent_text(user_profile_sub_query)

# Use glue to build the final query with preserved indentation
final_query <- glue("
SELECT *
FROM (

{indented_union_query}

  UNION ALL

{user_profile_sub_query}

) t
WHERE COALESCE(street_num, street_name, apartment_num, city, state, zip_code, country, cross_street_1, cross_street_2, address_line_1, address_line_2) IS NOT NULL
ORDER BY Connect_ID, address_nickname
", .trim = FALSE)

# Display the final query in the console
cat(final_query, "\n")

# Save the final query to a file
writeLines(final_query, "address_query.sql")
