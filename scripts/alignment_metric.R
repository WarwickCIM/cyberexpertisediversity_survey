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


scenarios <- read.csv("data/raw/cyber_expertise_diversity_survey_scenarios.csv") |> 
  mutate(id = row_number(), .before = 1)


# Functions ---------------------------------------------------------------

calc_indicator <- function(df){
  # This indicator function calculates the value to be used as indicator for a
  # given dataframe. It will check the response values from a dataframe and
  # assign an indicator that will be the response, capped by the specialism
  # threshold values.
  
  # We create an empty dataset which we will be populating in the loop below.
  df_indicator <- data.frame()
  
  for(id_val in 1:nlevels(df$id)) {
    
    df_filtered <- df |>
      # tmp_df_indicator <- comb_personal |> 
      filter(id == id_val)
    # Combine with comb_specialisms dataframe.
    
    tmp_df_indicator <- comb_specialism |> 
      left_join(df_filtered, by = c("Expertise_clean" = "name")) |> 
      # Create a new variable based on the thresholds.
      mutate(indicator = case_when(
        response >= Threshold ~ Threshold,
        .default = response)
      ) |> 
      # relocate(id, .before = 1) |> 
      relocate(response, .before = indicator)
    
    if (nrow(df_indicator) == 0) {
      df_indicator <- tmp_df_indicator
    } else {
      df_indicator <-  df_indicator |> 
        bind_rows(tmp_df_indicator)
    }
  }
  
  return(df_indicator)
  
}

#' Calculate alignment metric
#'
#' @param df 
#' @param alignment_type is a string either containing "Personal" or  "Scenario".
#'
#' @returns a dataframe 
#' @export
#'
#' @examples
calc_alignment_index <- function(df, type = NULL) {
  
  # ref_value <- enquo(ref_value)
  # type <- as.name(type)
  
  df_alignment <- df |> 
    group_by(id, Specialism) |> 
    summarise(
      threshold_sum = sum(Threshold),
      indicator_sum = sum(indicator),
      indicator_mean = mean(indicator),
      indicator_max = max(indicator),
      indicator_min = min(indicator)
    )
  
  if (type == "personal"){
    df_alignment <- df_alignment |> 
      mutate(alignment_index =  indicator_sum / threshold_sum )
  } else {
    df_alignment <- df_alignment |> 
      mutate(alignment_index =  threshold_sum / indicator_sum)
  }
  
  df_alignment <- df_alignment |> 
    mutate(alignment_type = type, .before = threshold_sum)
  
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

comb_personal <- responses |> 
  select(id, starts_with("expertise_comb")) |> 
  pivot_longer(!id, values_to = "response") |> 
  # Remove prefix so we can join with specialisms dataframe.
  mutate(name = str_remove(name, "expertise_comb_"),
         id = as.factor(id)) |> 
  calc_indicator()

comb_scenario <- scenarios |> 
  select(id, starts_with("scenario_expertise_")) |> 
  pivot_longer(!id, values_to = "response") |> 
  # Remove prefix so we can join with specialisms dataframe.
  mutate(name = str_remove(name, "scenario_expertise_portfolio_"),
         id = as.factor(id)) |> 
  calc_indicator()


# Personal alignment ----------------------------------------------------

# where test values (X) are the person’s comb (responses) and the reference
# values (Y) are the specialism comb.
alignment_personal_summary <- comb_personal |> 
  group_by(id, Specialism) |> 
  summarise(
    threshold_sum = sum(Threshold),
    indicator_sum = sum(indicator),
    indicator_mean = mean(indicator),
    indicator_max = max(indicator),
    indicator_min = min(indicator),
    alignment_index = indicator_sum / threshold_sum
  ) |> 
  mutate(alignment_type = "personal", .before = threshold_sum)

readr::write_csv(alignment_personal_summary, 
          file = "data/processed/alignment_personal_summary.csv")


# Reshape the dataset to a wider format, so it can be combined with responses.
alignment_personal <- alignment_personal_summary |> 
  pivot_wider(id_cols = id, names_from = Specialism, 
              values_from = alignment_index) |> 
  janitor::clean_names()

readr::write_csv(alignment_personal, 
          file = "data/processed/alignment_personal.csv")


# Scenarios alignment -----------------------------------------------------

# Scenarios alignment, where test values (X) are the specialism comb and the
# reference values (Y) are the scenario comb.
alignment_scenarios_summary <- comb_scenario |> 
  group_by(id, Specialism) |> 
  summarise(
    threshold_sum = sum(Threshold),
    indicator_sum = sum(indicator),
    indicator_mean = mean(indicator),
    indicator_max = max(indicator),
    indicator_min = min(indicator),
    alignment_index =  threshold_sum / indicator_sum
  ) |> 
  mutate(alignment_type = "scenarios", .before = threshold_sum) 

test <- calc_alignment_index(comb_scenario, type = "scenarios")

all.equal(alignment_scenarios_summary, test)


# Reshape the dataset to a wider format, so it can be combined with responses.
scenarios_alignment <- scenarios_alignment_summary |> 
  pivot_wider(id_cols = id, names_from = Specialism, 
              values_from = alignment_index) |> 
  janitor::clean_names()

readr::write_csv(scenarios_alignment, 
                 file = "data/processed/scenarios_alignment.csv")


# Scenarios' permutations -------------------------------------------------

calc_permuted_index <- function(df, permutations_n = 3) {
  df_permutations <- df |>
    group_by(id) |>
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
        df$max_threshold_value[df$id == id &
                                 df$Specialism %in% strsplit(permutation, ", ")[[1]]]
      ),
      indicator_sum = sum(
        df$indicator_sum[df$id == id &
                           df$Specialism %in% strsplit(permutation, ", ")[[1]]]
      )
    ) |>
    ungroup() |>
    mutate(
      alignment_index = indicator_sum / threshold_sum,
      n_permutations = permutations_n
    )

  return(df_permutations)
}

scenarios_alignment_permutations_2 <- calc_permuted_index(scenarios_alignment_summary, 2)
scenarios_alignment_permutations_3 <- calc_permuted_index(scenarios_alignment_summary, 3)

write.csv(scenarios_alignment_permutations_2, "data/processed/scenarios_alignment_permutations_2.csv")
write.csv(scenarios_alignment_permutations_3, "data/processed/scenarios_alignment_permutations_3.csv")