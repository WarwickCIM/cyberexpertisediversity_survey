library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

# Parameters --------------------------------------------------------------

# Each specialism has a series of expertises that are considered to be core,
# relevant or wider expertises.
# Edit the weight of each value below.

value_core <- 90
value_relevant <- 60
value_wider <- 30
value_NA <- 0

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
# using read_csv to preserve column names for further manipulation.
specialisms <- read_csv("data/raw/specialisms.csv")


scenarios <- read.csv("data/raw/cyber_expertise_diversity_survey_scenarios.csv") |>
  mutate(id = row_number(), .before = 1)


# Functions ---------------------------------------------------------------

calc_indicator <- function(df) {
  # This indicator function calculates the value to be used as indicator for a
  # given dataframe. It will check the response values from a dataframe and
  # assign an indicator that will be the response, capped by the specialism
  # threshold values.

  # We create an empty dataset which we will be populating in the loop below.
  df_indicator <- data.frame()

  for (id_val in 1:nlevels(df$id)) {
    df_filtered <- df |>
      filter(id == id_val)
    
    # Combine with comb_specialisms dataframe.
    tmp_df_indicator <- comb_specialism |>
      left_join(df_filtered, by = c("Expertise_clean" = "name")) |>
      # Create a new variable based on the thresholds.
      mutate(indicator = case_when(
        response >= Threshold ~ Threshold,
        .default = response
      )) |>
      # relocate(id, .before = 1) |>
      relocate(response, .before = indicator)

    if (nrow(df_indicator) == 0) {
      df_indicator <- tmp_df_indicator
    } else {
      df_indicator <- df_indicator |>
        bind_rows(tmp_df_indicator)
    }
  }

  return(df_indicator)
}

calc_alignment_index <- function(df, test = NULL, reference = NULL) {
  # Convert strings to symbols for tidy evaluation
  test <- ensym(test)
  reference <- ensym(reference)

  df_alignment <- df |>
    group_by(id, Specialism) |>
    summarise(
      reference_sum = sum({{ reference }}),
      test_sum = sum({{ test }})
    ) |>
    mutate(alignment_index = test_sum / reference_sum)

  return(df_alignment)
}


# Combs -------------------------------------------------------------------

# This is the specialisms dataset, in a long format, with threshold values,
# according to core, relevant or wider values.
comb_specialism <- specialisms |>
  # Reshape into long format is needed to replace values.
  pivot_longer(!Specialism, names_to = "Expertise", values_to = "Value") |>
  mutate(Expertise = as.factor(Expertise)) |>
  # Remove expertise that are not relevant to specialism.
  #filter(!is.na(Value)) |>
  # Create a new variable based on defined threshold values.
  mutate(Threshold = case_when(
    Value == "Core" ~ value_core,
    Value == "Related" ~ value_relevant,
    Value == "Wider" ~ value_wider,
    is.na(Value) ~ value_NA
  ), ) |>
  # Renaming values to match responses' variables.
  mutate(
    Expertise_clean = tolower(Expertise), .after = Expertise,
    Expertise_clean = str_replace_all(Expertise_clean, " ", "_"),
    Expertise_clean = str_remove_all(Expertise_clean, ","),
    Expertise_clean = str_remove_all(Expertise_clean, "_&")
  ) |>
  # Manually revalue some expertises to match survey's variables.
  mutate(Expertise_clean = case_when(
    Expertise_clean == "law_regulation" ~ "cyber_security_law_regulation",
    Expertise_clean == "human_factors" ~ "human_factors_and_usable_security",
    Expertise_clean == "physical_layer_telecoms_security" ~ "physical_layer_and_telecommunications_security",
    .default = as.character(Expertise_clean)
  ))

comb_personal <- responses |>
  select(id, starts_with("expertise_comb")) |>
  pivot_longer(!id, values_to = "response") |>
  # Remove prefix so we can join with specialisms dataframe.
  mutate(
    name = str_remove(name, "expertise_comb_"),
    id = as.factor(id)
  ) |>
  calc_indicator()

comb_scenario <- scenarios |>
  select(id, starts_with("scenario_expertise_")) |>
  pivot_longer(!id, values_to = "response") |>
  # Remove prefix so we can join with specialisms dataframe.
  mutate(
    name = str_remove(name, "scenario_expertise_portfolio_"),
    id = as.factor(id)
  ) |>
  calc_indicator()


# Personal alignment ----------------------------------------------------

# where test values (X) are the person’s comb (responses) and the reference
# values (Y) are the specialism comb.
alignment_personal_long <- calc_alignment_index(
  comb_personal,
  test = "indicator", reference = "Threshold"
) |>
  mutate(alignment_type = "personal")

# Reshape the dataset to a wider format, so it can be combined with responses.
alignment_personal <- alignment_personal_long |>
  pivot_wider(
    id_cols = id, names_from = Specialism,
    values_from = alignment_index
  ) |>
  janitor::clean_names()


write_csv(alignment_personal_long,
  file = "data/processed/alignment_personal_long.csv"
)

write_csv(alignment_personal,
  file = "data/processed/alignment_personal.csv"
)


# Scenarios alignment -----------------------------------------------------

# Scenarios alignment, where test values (X) are the specialism comb and the
# reference values (Y) are the scenario comb.
alignment_scenarios_long <- calc_alignment_index(
  comb_scenario,
  test = "indicator", reference = "response"
) |>
  mutate(alignment_type = "scenario")

# Reshape the dataset to a wider format, so it can be combined with responses.
alignment_scenarios <- alignment_scenarios_long |>
  pivot_wider(
    id_cols = id, names_from = Specialism,
    values_from = alignment_index
  ) |>
  janitor::clean_names()


write_csv(alignment_scenarios_long,
  file = "data/processed/alignment_scenarios_long.csv"
)

write_csv(alignment_scenarios,
  file = "data/processed/alignment_scenarios.csv"
)


# Scenarios' permutations original version-------------------------------------------------

#calc_permutation_alignment <- function(df, n) {
#  df |> 
#    group_by(id) |> 
#      permutations = list(combn(unique(Specialism), n, simplify = FALSE)),
#    summarise(
#      .groups = "drop"
#    ) |> 
#    unnest(permutations) |> 
#    mutate(
#      permutation = map_chr(permutations, ~ paste(.x, collapse = ", ")),
#      test_max = map_dbl(permutations, ~ max(df$test_sum[df$id == cur_group_id() & df$Specialism %in% .x])),
#      reference_max = map_dbl(permutations, ~ max(df$reference_sum[df$id == cur_group_id() & df$Specialism %in% .x])),
#      alignment_index = test_max / reference_max,
#      n_permutations = n
#    ) |> 
#    select(-permutations)
#}


#alignment_scenarios_2_permutations <- calc_permutation_alignment(alignment_scenarios_long, 2)
#alignment_scenarios_3_permutations <- calc_permutation_alignment(alignment_scenarios_long, 3)

calc_permutation_alignment <- function(df, n) {
  df |> 
    group_by(id) |> 
    summarise(
      permutations = list(combn(unique(Specialism), n, simplify = FALSE)),
      .groups = "drop"
    ) |> 
    # Process each id to find best permutation
    rowwise() |>
    mutate(
      results = list(map_dfr(permutations, function(p) {
        # Filter data for current id and permutation
        current_id <- id
        id_data <- df |> filter(id == current_id, Specialism %in% p)
        
        # Calculate test_sum
        test_sum <- id_data |>
          group_by(Expertise_clean) |>
          summarise(max_value = max(indicator, na.rm = TRUE), .groups = "drop") |>
          summarise(sum = sum(max_value, na.rm = TRUE)) |>
          pull(sum)
        
        # Calculate reference_sum
        reference_sum <- id_data |>
          group_by(Expertise_clean) |>
          summarise(max_value = max(response, na.rm = TRUE), .groups = "drop") |>
          summarise(sum = sum(max_value, na.rm = TRUE)) |>
          pull(sum)
        
        # Return a mini data frame with results
        tibble(
          permutation = paste(p, collapse = ", "),
          test_sum = test_sum,
          reference_sum = reference_sum,
          alignment_index = test_sum / reference_sum
        )
      }))
    ) |>
    # Get the best permutation for each id
    mutate(
      best_result = list(results |> slice_max(order_by = alignment_index, n = 1, with_ties = FALSE))
    ) |>
    select(-permutations, -results) |>
    unnest(best_result) |>
    # Add n_permutations
    mutate(n_permutations = n)
}

alignment_scenarios_1_permutations <- calc_permutation_alignment(comb_scenario, 1)
alignment_scenarios_2_permutations <- calc_permutation_alignment(comb_scenario, 2)
alignment_scenarios_3_permutations <- calc_permutation_alignment(comb_scenario, 3)
alignment_scenarios_4_permutations <- calc_permutation_alignment(comb_scenario, 4)
alignment_scenarios_5_permutations <- calc_permutation_alignment(comb_scenario, 5)

write.csv(alignment_scenarios_1_permutations, "data/processed/max_alignment_scenarios_1_permutations.csv")
write.csv(alignment_scenarios_2_permutations, "data/processed/max_alignment_scenarios_2_permutations.csv")
write.csv(alignment_scenarios_3_permutations, "data/processed/max_alignment_scenarios_3_permutations.csv")
write.csv(alignment_scenarios_4_permutations, "data/processed/max_alignment_scenarios_4_permutations.csv")
write.csv(alignment_scenarios_5_permutations, "data/processed/max_alignment_scenarios_5_permutations.csv")
