library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(glue)
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
  st_name  = "Full Street name",
  apt_num  = "Apartment, suite, unit, building, etc.",
  city     = "City",
  state    = "State/Province",
  zip      = "Zip code",
  country  = "Country"
)

get_field <- function(comp_vec, var_vec, keyword) {
  idx <- str_detect(tolower(var_vec), tolower(keyword))
  if (any(idx)) {
    return(comp_vec[idx][1])
  } else {
    return(NA_character_)
  }
}

# Helper to pad address number with two digits
pad_address <- function(n) sprintf("%02d", as.integer(n))

# -------------------------------
# (A) Home Address Mapping (HOMEADD)
# -------------------------------
df_home <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) &
           str_detect(grid_id_source_question_name, "HOMEADD")) %>%
  extract(grid_id_source_question_name, 
          into = c("group_type", "address_num"),
          regex = "HOMEADD(\\d+)_(\\d+)",
          convert = TRUE)

df_home_grp1 <- df_home %>%
  filter(group_type == 1) %>%
  group_by(address_num) %>%
  summarise(
    address_src_quest_cid = first(src_concept_id),
    st_num_cid   = get_field(component_concept_id, variable_label, field_map["st_num"]),
    st_name_cid  = get_field(component_concept_id, variable_label, field_map["st_name"]),
    apt_num_cid  = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    city_cid     = get_field(component_concept_id, variable_label, field_map["city"]),
    state_cid    = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_cid      = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_cid  = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_home_grp2 <- df_home %>%
  filter(group_type == 2) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_1_src_cid = first(src_concept_id),
    city_fu_cid   = get_field(component_concept_id, variable_label, field_map["city"]),
    state_fu_cid  = get_field(component_concept_id, variable_label, field_map["state"]),
    zip_fu_cid    = get_field(component_concept_id, variable_label, field_map["zip"]),
    country_fu_cid= get_field(component_concept_id, variable_label, field_map["country"])
  )

df_home_grp3 <- df_home %>%
  filter(group_type == 3) %>%
  group_by(address_num) %>%
  summarise(
    follow_up_2_src_cid = first(src_concept_id),
    cross_st_1_cid = first(component_concept_id),
    cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )

df_home_mapping <- df_home_grp1 %>%
  full_join(df_home_grp2, by = "address_num") %>%
  full_join(df_home_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("home_address_", pad_address(address_num)),
         address_type = "Home") %>%
  select(address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type)

# -------------------------------
# (B) Seasonal Address Mapping (SEASADD)
# -------------------------------
df_seas <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) &
           str_detect(grid_id_source_question_name, "SEASADD")) %>%
  extract(grid_id_source_question_name, 
          into = c("group_type", "address_num"),
          regex = "SEASADD(\\d+)_(\\d+)",
          convert = TRUE)

df_seas_grp1 <- df_seas %>%
  filter(group_type == 1) %>%
  group_by(address_num) %>%
  summarise(
    seas_address_src_quest_cid = first(src_concept_id),
    seas_st_num_cid  = get_field(component_concept_id, variable_label, field_map["st_num"]),
    seas_st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
    seas_apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    seas_city_cid    = get_field(component_concept_id, variable_label, field_map["city"]),
    seas_state_cid   = get_field(component_concept_id, variable_label, field_map["state"]),
    seas_zip_cid     = get_field(component_concept_id, variable_label, field_map["zip"]),
    seas_country_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_seas_grp2 <- df_seas %>%
  filter(group_type == 2) %>%
  group_by(address_num) %>%
  summarise(
    seas_follow_up_1_src_cid = first(src_concept_id),
    seas_city_fu_cid  = get_field(component_concept_id, variable_label, field_map["city"]),
    seas_state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    seas_zip_fu_cid   = get_field(component_concept_id, variable_label, field_map["zip"]),
    seas_country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_seas_grp3 <- df_seas %>%
  filter(group_type == 3) %>%
  group_by(address_num) %>%
  summarise(
    seas_follow_up_2_src_cid = first(src_concept_id),
    seas_cross_st_1_cid = first(component_concept_id),
    seas_cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )

df_seas_mapping <- df_seas_grp1 %>%
  full_join(df_seas_grp2, by = "address_num") %>%
  full_join(df_seas_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("seasonal_address_", pad_address(address_num)),
         address_type = "Seasonal") %>%
  select(seas_address_src_quest_cid, address_nickname, seas_st_num_cid, seas_st_name_cid, seas_apt_num_cid,
         seas_city_cid, seas_state_cid, seas_zip_cid, seas_country_cid,
         seas_follow_up_1_src_cid, seas_city_fu_cid, seas_state_fu_cid, seas_zip_fu_cid, seas_country_fu_cid,
         seas_follow_up_2_src_cid, seas_cross_st_1_cid, seas_cross_st_2_cid, address_type) %>%
  rename(
    address_src_quest_cid = seas_address_src_quest_cid,
    st_num_cid = seas_st_num_cid,
    st_name_cid = seas_st_name_cid,
    apt_num_cid = seas_apt_num_cid,
    city_cid = seas_city_cid,
    state_cid = seas_state_cid,
    zip_cid = seas_zip_cid,
    country_cid = seas_country_cid,
    follow_up_1_src_cid = seas_follow_up_1_src_cid,
    city_fu_cid = seas_city_fu_cid,
    state_fu_cid = seas_state_fu_cid,
    zip_fu_cid = seas_zip_fu_cid,
    country_fu_cid = seas_country_fu_cid,
    follow_up_2_src_cid = seas_follow_up_2_src_cid,
    cross_st_1_cid = seas_cross_st_1_cid,
    cross_st_2_cid = seas_cross_st_2_cid
  )

# -------------------------------
# (C) Childhood Address Mapping (CHILDADD)
# -------------------------------
df_child <- df_dict %>%
  filter(!is.na(grid_id_source_question_name) &
           str_detect(grid_id_source_question_name, "CHILDADD"))

df_child_grp1 <- df_child %>%
  filter(str_detect(grid_id_source_question_name, "^CHILDADD1")) %>%
  mutate(address_num = 1) %>%  
  group_by(address_num) %>%
  summarise(
    childhood_address_src_quest_cid = first(src_concept_id),
    child_st_num_cid = get_field(component_concept_id, variable_label, field_map["st_num"]),
    child_st_name_cid = get_field(component_concept_id, variable_label, field_map["st_name"]),
    child_apt_num_cid = get_field(component_concept_id, variable_label, field_map["apt_num"]),
    child_city_cid    = get_field(component_concept_id, variable_label, field_map["city"]),
    child_state_cid   = get_field(component_concept_id, variable_label, field_map["state"]),
    child_zip_cid     = get_field(component_concept_id, variable_label, field_map["zip"]),
    child_country_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_child_grp2 <- df_child %>%
  filter(str_detect(grid_id_source_question_name, "^CHILDADD2")) %>%
  mutate(address_num = 1) %>%
  group_by(address_num) %>%
  summarise(
    child_follow_up_1_src_cid = first(src_concept_id),
    child_city_fu_cid  = get_field(component_concept_id, variable_label, field_map["city"]),
    child_state_fu_cid = get_field(component_concept_id, variable_label, field_map["state"]),
    child_zip_fu_cid   = get_field(component_concept_id, variable_label, field_map["zip"]),
    child_country_fu_cid = get_field(component_concept_id, variable_label, field_map["country"])
  )

df_child_grp3 <- df_child %>%
  filter(str_detect(grid_id_source_question_name, "^CHILDADD3")) %>%
  mutate(address_num = 1) %>%
  group_by(address_num) %>%
  summarise(
    child_follow_up_2_src_cid = first(src_concept_id),
    child_cross_st_1_cid = first(component_concept_id),
    child_cross_st_2_cid = ifelse(n() > 1, nth(component_concept_id, 2), NA_character_)
  )

df_child_mapping <- df_child_grp1 %>%
  full_join(df_child_grp2, by = "address_num") %>%
  full_join(df_child_grp3, by = "address_num") %>%
  mutate(address_nickname = paste0("childhood_address_", pad_address(address_num)),
         address_type = "Childhood") %>%
  select(childhood_address_src_quest_cid, address_nickname, child_st_num_cid, child_st_name_cid, child_apt_num_cid,
         child_city_cid, child_state_cid, child_zip_cid, child_country_cid,
         child_follow_up_1_src_cid, child_city_fu_cid, child_state_fu_cid, child_zip_fu_cid, child_country_fu_cid,
         child_follow_up_2_src_cid, child_cross_st_1_cid, child_cross_st_2_cid, address_type) %>%
  rename(
    address_src_quest_cid = childhood_address_src_quest_cid,
    st_num_cid = child_st_num_cid,
    st_name_cid = child_st_name_cid,
    apt_num_cid = child_apt_num_cid,
    city_cid = child_city_cid,
    state_cid = child_state_cid,
    zip_cid = child_zip_cid,
    country_cid = child_country_cid,
    follow_up_1_src_cid = child_follow_up_1_src_cid,
    city_fu_cid = child_city_fu_cid,
    state_fu_cid = child_state_fu_cid,
    zip_fu_cid = child_zip_fu_cid,
    country_fu_cid = child_country_fu_cid,
    follow_up_2_src_cid = child_follow_up_2_src_cid,
    cross_st_1_cid = child_cross_st_1_cid,
    cross_st_2_cid = child_cross_st_2_cid
  )

# -------------------------------
# (D) Current Work Address Mapping (CURWORK)
# -------------------------------
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
  mutate(address_nickname = paste0("current_work_address_", pad_address(address_num)),
         address_type = "Current Work") %>%
  select(address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type)

# -------------------------------
# (E) Previous Work Address Mapping (PREWORK)
# -------------------------------
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
  mutate(address_nickname = paste0("previous_work_address_", pad_address(address_num)),
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
  mutate(address_nickname = paste0("school_address_", pad_address(address_num)),
         address_type = "School") %>%
  select(school_address_src_quest_cid, address_nickname, st_num_cid, st_name_cid, apt_num_cid,
         city_cid, state_cid, zip_cid, country_cid,
         follow_up_1_src_cid, city_fu_cid, state_fu_cid, zip_fu_cid, country_fu_cid,
         follow_up_2_src_cid, cross_st_1_cid, cross_st_2_cid, address_type) %>%
  rename(address_src_quest_cid = school_address_src_quest_cid)

# -------------------------------
# Combine All Mappings into One Sheet
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
