library(dplyr)
library(purrr)
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
# using readr::read_csv to preserve column names for further manipulation.
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



# Specialism alignment ----------------------------------------------------


# Combine responses with specialisms

# We create an empty dataset which we will be populating in the loop below.
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


alignment_index <- function(df, type = NULL) {
  
  if (!type %in% c("scenario", "specialism")) {
    stop("type needs to be either `scenario` or `specialism`")
  }
  
  df_alignment <- df |> 
    group_by(id, Specialism) |> 
    summarise(max_threshold_value = sum(Threshold),
              alignment_sum = sum(response_mod),
              alignment_index = alignment_sum/max_threshold_value,
              alignment_mean = mean(response_mod),
              max = max(response),
              min = min(response)) |> 
    mutate(alignment_type = type)

  return(df_alignment)
  
}

specialisms_respondent <- alignment_index(
  specialisms_respondent_raw, 
  "specialism"
)

readr::write_csv(specialisms_respondent, 
          file = "data/processed/specialisms_respondent.csv")


# Reshape the dataset to a wider format, so it can be combined with responses.
specialisms_respondent_long <- specialisms_respondent |> 
  pivot_wider(id_cols = id, names_from = Specialism, 
              values_from = alignment_index) |> 
  janitor::clean_names()

readr::write_csv(specialisms_respondent_long, 
          file = "data/processed/specialisms_respondent_long.csv")

# 
# responses_specialism2 <- specialisms_respondent |> 
#   pivot_wider(id_cols = id, names_from = Specialism, 
#               values_from = alignment_mean) |> 
#   janitor::clean_names()
# 
# 
# write_csv(responses_specialism2, 
#           file = "data/processed/responses_specialism_option2.csv")


# Scenarios alignment -----------------------------------------------------

scenarios <- read.csv("data/raw/cyber_expertise_diversity_survey_scenarios.csv") |> 
  mutate(id = row_number(), .before = 1)

# We create an empty dataset which we will be populating in the loop below.
scenarios_alignment_raw <- data.frame()

# Generate a long version of specialisms dataframe with actual values for each
# response.
for(scenario in scenarios$id) {
  tmp_responses_scenario <- scenarios |> 
    filter(id == scenario) |> 
    select(id, starts_with("scenario_expertise_portfolio_")) |> 
    pivot_longer(!id, values_to = "response") |> 
    # Remove prefix so we can join with specialisms dataframe.
    mutate(name = str_remove(name, "scenario_expertise_portfolio_"))
  
  tmp_scenarios_raw <- specialisms_long |> 
    # Combine with specialisms_long dataframe.
    left_join(tmp_responses_scenario, by = c("Expertise_clean" = "name")) |> 
    relocate(id, .before = 1) |> 
    # Create a new variable based on the thresholds.
    mutate(response_mod = case_when(
      response >= Threshold ~ Threshold,
      .default = response
    ))
  
  # Create a dataframe containing all values for all survey responses.
  scenarios_alignment_raw <- scenarios_alignment_raw |> 
    bind_rows(tmp_scenarios_raw)
  
  remove(tmp_scenarios_raw)
  
}


scenarios_alignment <- alignment_index(scenarios_alignment_raw, "scenario") |> 
  rename(scenario_id = id)

readr::write_csv(scenarios_respondent, 
                 file = "data/processed/scenarios_respondent.csv")


# Reshape the dataset to a wider format, so it can be combined with responses.
scenarios_alignment_long <- scenarios_alignment |> 
  pivot_wider(id_cols = scenario_id, names_from = Specialism, 
              values_from = alignment_index) |> 
  janitor::clean_names()

readr::write_csv(scenarios_alignment_long, 
                 file = "data/processed/scenarios_respondent_long.csv")



# Scenarios' permutations -------------------------------------------------

# Create permutations of 3 different values of specialism for each scenario
calc_permuted_index <- function(df, permutations_n = 3) {
  df_permutations <- df |>
    group_by(scenario_id) |>
    summarise(
      permutations = list(combn(unique(Specialism), permutations_n, simplify = FALSE)),
      .groups = "drop"
    ) |>
    unnest(permutations) |>
    mutate(permutation = map_chr(permutations, ~ paste(.x, collapse = ", "))) |>
    select(-permutations) |>
    rowwise() |>
    mutate(
      threshold_sum = sum(
        df$max_threshold_value[df$scenario_id == scenario_id &
          df$Specialism %in% strsplit(permutation, ", ")[[1]]]
      ),
      values_sum = sum(
        df$alignment_sum[df$scenario_id == scenario_id &
          df$Specialism %in% strsplit(permutation, ", ")[[1]]]
      )
    ) |>
    ungroup() |>
    mutate(
      alignment_index = values_sum / threshold_sum,
      n_permutations = permutations_n
    )

  return(df_permutations)
}

scenarios_alignment_permutations_2 <- calc_permuted_index(scenarios_alignment, 2)
scenarios_alignment_permutations_3 <- calc_permuted_index(scenarios_alignment, 3)
scenarios_alignment_permutations_4 <- calc_permuted_index(scenarios_alignment, 4)

write.csv(scenarios_alignment_permutations_2, "data/processed/scenarios_alignment_permutations_2.csv")
write.csv(scenarios_alignment_permutations_3, "data/processed/scenarios_alignment_permutations_3.csv")
write.csv(scenarios_alignment_permutations_4, "data/processed/scenarios_alignment_permutations_4.csv")