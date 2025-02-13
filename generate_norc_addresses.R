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
df <- read_excel(mapping_file, sheet = 1) %>% mutate(across(everything(), as.character))

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
  indenteD_lines <- paste0("    ", lines, collapse = "\n")
  return(indenteD_lines)
}

# Build a list of complete SELECT statements for each row
select_statements <- apply(df, 1, function(r) {
  sql_expr <- generate_address_select_expression(r)
  glue("SELECT\n{sql_expr}\nFROM `{project}.{dataset}.{table}`")
})

# Combine all SELECT statements with UNION ALL, and add an ORDER BY clause at the end.
final_query <- paste(select_statements, collapse = "\n\nUNION ALL\n\n")
final_query <- paste(final_query, "ORDER BY Connect_ID, address_nickname", sep = "\n\n")

# Print the final query
cat("Generated Query:\n")
cat(final_query, "\n")

# Save the final query to a file
writeLines(final_query, "address_query.sql")
cat("Query saved to address_query.sql\n")
