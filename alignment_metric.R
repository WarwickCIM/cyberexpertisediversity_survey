library(dplyr)
library(tidyr)
library(stringr)


# Parameters --------------------------------------------------------------

# Each specialism has a series of expertises that are considered to be core,
# relevant or wider expertises.
# Edit the weight of each value below.

value_core <- 90
value_relevant <- 60
value_wider <- 30


# Load data ---------------------------------------------------------------

# Load responses from GitHub Repo: https://github.com/WarwickCIM/cyberexpertisediversity_survey_data

# TODO: implement an automated way to load a dataset from a private repo. 
# Workaround:
# 1. Visit https://github.com/WarwickCIM/cyberexpertisediversity_survey_data/blob/main/data/cyber_expertise_diversity_survey_responses.csv
# 2. Click on "Download raw file" (upper right corner of the file)
# 3. Move the file to the folder /data/raw/ in this project.
# 4. Run the code below.

responses <- read.csv("data/raw/cyber_expertise_diversity_survey_responses.csv") |> 
  # mutate(id = uuid::UUIDgenerate(use.time = FALSE), .before = recorded_date)
  mutate(id = row_number(), .before = recorded_date)

# Dataset with a classification of Specialisms and related expertises.
specialisms <- readr::read_csv("data/raw/specialisms.csv") 


# Data preparation --------------------------------------------------------

# Prepares a dataframe with specialisms information so it is easier to operate
# with and to combine with responses.
specialisms_long <- specialisms |>
  # Reshape into long format.
  pivot_longer(!Specialism, names_to = "Expertise", values_to = "Value") |>
  mutate(Expertise = as.factor(Expertise)) |> 
  # Remove empty rows.
  filter(!is.na(Value)) |> 
  # Create a new variable based on defined threshold values.
  mutate(Threshold = case_when(
    Value == "Core" ~ value_core,
    Value == "Related" ~ value_relevant,
    Value == "Wider" ~ value_wider,
    ),
  ) |> 
  # Renaming values to match responses' variables.
  mutate(Expertise_clean = tolower(Expertise), .after = Expertise,
         Expertise_clean = str_replace_all(Expertise_clean, " ", "_"),
         Expertise_clean = str_remove_all(Expertise_clean, ","),
         Expertise_clean = str_remove_all(Expertise_clean, "_&")) |> 
  # Manually revalue some expertises to match survey's variables.
  mutate(Expertise_clean = case_when(
    Expertise_clean == "law_regulation" ~ "cyber_security_law_regulation",
    Expertise_clean == "human_factors" ~ "human_factors_and_usable_security",
    Expertise_clean == "physical_layer_telecoms_security" ~ "physical_layer_and_telecommunications_security",
    .default = as.character(Expertise_clean)
  ))


# Combine responses with specialisms --------------------------------------

# We create an empy dataset which we will be populating in the loop below.
specialisms_respondent_raw <- data.frame()

# Generate a long version of specialisms dataframe with actual values for each
# response.
for(response in responses$id) {
  tmp_responses <- responses |> 
    filter(id == response) |> 
    select(id, starts_with("expertise_comb_")) |> 
    pivot_longer(!id, values_to = "response") |> 
    # Remove prefix so we can join with specialisms dataframe.
    mutate(name = str_remove(name, "expertise_comb_"))
  
  tmp_specialisms_respondent_raw <- specialisms_long |> 
    # Combine with specialisms_long dataframe.
    left_join(tmp_responses, by = c("Expertise_clean" = "name")) |> 
    relocate(id, .before = 1) |> 
    # Create a new variable based on the thresholds.
    mutate(response_mod = case_when(
      response >= Threshold ~ Threshold,
      .default = response
    ))
  
  # Create a dataframe containing all values for all survey responses.
  specialisms_respondent_raw <- specialisms_respondent_raw |> 
    bind_rows(tmp_specialisms_respondent_raw)
  
  remove(tmp_specialisms_respondent_raw)
  
}

# Calculate alignment values by response and specialisms. We are exploring multiple options here.
specialisms_respondent <- specialisms_respondent_raw |> 
  group_by(id, Specialism) |> 
  summarise(max_threshold_value = sum(Threshold),
            alignment_sum = sum(response_mod),
            alignment_sum_relative = alignment_sum/max_threshold_value,
            alignment_mean = mean(response_mod),
            max = max(response),
            min = min(response))

write_csv(specialisms_respondent, 
          file = "data/processed/specialisms_respondent.csv")


# Reshape the dataset to a wider format, so it can be combined with responses.
responses_specialism <- specialisms_respondent |> 
  pivot_wider(id_cols = id, names_from = Specialism, 
              values_from = alignment_sum_relative) |> 
  janitor::clean_names()

write_csv(responses_specialism, 
          file = "data/processed/responses_specialism.csv")
