summarise_column <- function(df, column) {
  
  df %>%
    count(!!sym(column), name = "count") %>%
    mutate(
      percentage = scales::percent(count / sum(count), accuracy = 0.1)
    )
}
