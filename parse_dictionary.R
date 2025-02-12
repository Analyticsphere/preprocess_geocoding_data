library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)
library(janitor)

# -------------------------------
# 1. Read and Prepare the Dictionary
# -------------------------------
dict_file  <- "dictionary.xlsx"             
sheet_name <- "MasterSurveyComb_20250210"   
df_dict <- read_excel(dict_file, sheet = sheet_name, col_types = "text") %>% 
  clean_names()

df_dict <- df_dict %>%
  rename(src_concept_id       = concept_id_7,
         component_concept_id = concept_id_14,
         secondary_source_concept_id = concept_id_5) %>% 
  filter(secondary_source_concept_id == "716117817") %>% 
  select(src_concept_id, 
         current_source_question, 
         component_concept_id, 
         current_question_text, 
         grid_id_source_question_name,
         variable_label)

# -------------------------------
# 2. Define a Field Map and Helper Function
# -------------------------------
field_map <- c(
  st_num   = "Street number",
  st_name  = "Full Street name",    # adjust if needed
  apt_num  = "Apartment, suite, unit, building, etc.",
  city     = "City",
  state    = "State/Province",
  zip      = "Zip code",
  country  = "Country"
)

# Helper: takes component_concept_id and variable_label vectors plus a keyword
get_field <- function(comp_vec, var_vec, keyword) {
  idx <- str_detect(tolower(var_vec), tolower(keyword))
  if (any(idx)) {
    return(comp_vec[idx][1])
  } else {
    return(NA_character_)
  }
}

# -------------------------------
# 3. Build a Mapping Function for Standard Patterns
# -------------------------------
build_mapping <- function(df, prefix, nickname_prefix, addr_type, regex_pattern = paste0(prefix, "(\\d+)_(\\d+)")) {
  df_sub <- df %>%
    filter(!is.na(grid_id_source_question_name) & str_detect(grid_id_source_question_name, prefix)) %>%
    extract(grid_id_source_question_name, into = c("group_type", "address_num"), regex = regex_pattern, convert = TRUE)
  
  grp1 <- df_sub %>%
    filter(group_type == 1) %>%
    group_by(address_num) %>%
    summarise(
      address_src_quest_cid = first(src_concept_id),
      st_num_cid = get_field(component_concept_id, variable_label, field_map["st_num"]),
      st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
      apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
      city_cid = get_field(component_concept_id, variable_label, field_map["city"]),
      state_cid = get_field(component_concept_id, variable_label, field_map["state"]),
      zip_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
      country_cid = get_field(component_concept_id, variable_label, field_map["country"])
    )
  
  grp2 <- df_sub %>%
    filter(group_type == 2) %>%
    group_by(address_num) %>%
    summarise(
      follow_up_1_src_cid = first(src_concept_id),
      city_fu_cid = get_field(component_concept_id, variable_label, field_map["city"]),
      state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
      zip_fu_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
      country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
    )
  
  grp3 <- df_sub %>%
    filter(group_type == 3) %>%
    group_by(address_num) %>%
    summarise(
      follow_up_2_src_cid = first(src_concept_id),
      cross_st_1_cid = first(component_concept_id),
      cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
    )
  
  mapping <- grp1 %>% 
    full_join(grp2, by = "address_num") %>% 
    full_join(grp3, by = "address_num") %>% 
    mutate(address_nickname = paste0(nickname_prefix, address_num),
           address_type = addr_type) %>% 
    select(address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
           city_cid, state_cid, zip_cid, country_cid,
           follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
           follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type)
  return(mapping)
}

# -------------------------------
# 4. Build Mappings for Address Types That Follow the Pattern
# -------------------------------
df_home_mapping     <- build_mapping(df_dict, "HOMEADD",    "home_address_",     "Home")
df_seas_mapping     <- build_mapping(df_dict, "SEASADD",    "seasonal_address_", "Seasonal")
df_child_mapping    <- build_mapping(df_dict, "CHILDADD",   "childhood_address_", "Childhood")
df_school_mapping   <- build_mapping(df_dict, "CURSCH",     "school_address_",   "School")
# (The above assume grid IDs like HOMEADD1_n, SEASADD1_n, CHILDADD1_n, CURSCH1_n)

# -------------------------------
# 5. Current and Previous Work Addresses (Handled Separately)
# -------------------------------
# For work addresses, the grid IDs do not include the underscore pattern.
# We assume:
#   - Current Work: "CURWORK1", "CURWORK2_SRC", "CURWORK3_SRC"
df_work <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) & str_detect(grid_id_source_question_name, "^CURWORK")) %>%
  mutate(address_num = 1,
         group_type = case_when(
           grid_id_source_question_name == "CURWORK1" ~ 1,
           grid_id_source_question_name == "CURWORK2_SRC" ~ 2,
           grid_id_source_question_name == "CURWORK3_SRC" ~ 3,
           TRUE ~ NA_real_
         ))
df_work_grp1 <- df_work %>%
  filter(group_type == 1) %>%
  group_by(address_num) %>%
  summarise(
    address_src_quest_cid = first(src_concept_id),
    st_num_cid = get_field(component_concept_id, variable_label, field_map["st_num"]),
    st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
    apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    city_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )
df_work_grp2 <- df_work %>%
  filter(group_type == 2) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_1_src_cid = first(src_concept_id),
    city_fu_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_fu_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )
df_work_grp3 <- df_work %>%
  filter(group_type == 3) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_2_src_cid = first(src_concept_id),
    cross_st_1_cid = first(component_concept_id),
    cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )
df_work_mapping <- df_work_grp1 %>%
  full_join(df_work_grp2, by = "address_num") %>%
  full_join(df_work_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("current_work_address_", address_num),
         address_type = "Current Work") %>%
  select(address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type)

# Previous Work addresses use grid IDs beginning with PREWORK.
df_prevwork <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) & str_detect(grid_id_source_question_name, "^PREWORK")) %>%
  mutate(address_num = 1)
df_prevwork_grp1 <- df_prevwork %>%
  filter(str_detect(grid_id_source_question_name, "^PREWORK1")) %>%
  group_by(address_num) %>%
  summarise(
    prev_work_src_quest_cid = first(src_concept_id),
    st_num_cid = get_field(component_concept_id, variable_label, field_map["st_num"]),
    st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
    apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    city_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )
df_prevwork_grp2 <- df_prevwork %>%
  filter(str_detect(grid_id_source_question_name, "^PREWORK2")) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_1_src_cid = first(src_concept_id),
    city_fu_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_fu_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )
df_prevwork_grp3 <- df_prevwork %>%
  filter(str_detect(grid_id_source_question_name, "^PREWORK3")) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_2_src_cid = first(src_concept_id),
    cross_st_1_cid = first(component_concept_id),
    cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )
df_prevwork_mapping <- df_prevwork_grp1 %>%
  full_join(df_prevwork_grp2, by = "address_num") %>%
  full_join(df_prevwork_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("previous_work_address_", address_num),
         address_type = "Previous Work") %>%
  select(prev_work_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type) %>%
  rename(address_src_quest_cid = prev_work_src_quest_cid)

# -------------------------------
# (F) School Address Mapping (CURSCH)
# -------------------------------
df_school <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) & str_detect(grid_id_source_question_name, "^CURSCH")) %>%
  mutate(address_num = 1)

df_school_grp1 <- df_school %>%
  filter(str_detect(grid_id_source_question_name, "^CURSCH1")) %>%
  group_by(address_num) %>%
  summarise(
    school_address_src_quest_cid = first(src_concept_id),
    st_num_cid = get_field(component_concept_id, variable_label, field_map["st_num"]),
    st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
    apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    city_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_school_grp2 <- df_school %>%
  filter(str_detect(grid_id_source_question_name, "^CURSCH2")) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_1_src_cid = first(src_concept_id),
    city_fu_cid = get_field(component_concept_id, variable_label, field_map["city"]),
    state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_fu_cid = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_school_grp3 <- df_school %>%
  filter(str_detect(grid_id_source_question_name, "^CURSCH3")) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_2_src_cid = first(src_concept_id),
    cross_st_1_cid = first(component_concept_id),
    cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )

df_school_mapping <- df_school_grp1 %>%
  full_join(df_school_grp2, by = "address_num") %>%
  full_join(df_school_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("school_address_", address_num),
         address_type = "School") %>%
  select(school_address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type) %>%
  rename(address_src_quest_cid = school_address_src_quest_cid)

# -------------------------------
# 6. Combine All Mappings into One Sheet
# -------------------------------
combined_mapping <- bind_rows(
  df_home_mapping,
  df_seas_mapping,
  df_child_mapping,
  df_work_mapping,
  df_prevwork_mapping,
  df_school_mapping
)

combined_mapping <- combined_mapping %>%
  select(address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid,
         address_type)

write_xlsx(combined_mapping, "address_concept_map.xlsx")
cat("Combined mapping saved to address_concept_map.xlsx\n")

