# Load required libraries
library(readr)
library(dplyr)
library(tidytext)
library(ggplot2)
library(scales)
library(ggrepel)
library(tidyr)
library(lubridate)

# Load the data
tweets_data <- read_csv("C:/Users/pshru/Desktop/Vs code/tweets.csv")

# Data pre-processing
tweets_data <- tweets_data %>%
  select(gender, text, tweet_created, retweet_count, fav_number) %>%
  mutate(
    gender = ifelse(gender %in% c("male", "female"), gender, "other"),
    tweet_created = as.Date(tweet_created, format = "%m/%d/%Y %H:%M"),
    month = floor_date(tweet_created, unit = "month")
  ) %>%
  filter(!is.na(gender))

# 1. Word Frequency Analysis
tweets_words <- tweets_data %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words)

word_frequency <- tweets_words %>%
  count(gender, word, sort = TRUE) %>%
  group_by(gender) %>%
  slice_max(n, n = 10) %>%
  ungroup()

# Create a single graph for word frequency by gender
ggplot(word_frequency, aes(x = reorder_within(word, n, gender), y = n, fill = gender)) +
  geom_col(show.legend = TRUE) +
  scale_x_reordered() +
  coord_flip() +
  labs(title = "Top 10 Words by Gender",
       x = NULL,
       y = "Count",
       fill = "Gender") +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 8),
        legend.position = "bottom")

ggsave("top_words_by_gender.png", width = 12, height = 8)


# Print the top 10 most used words by gender in descending order
word_frequency_list <- word_frequency %>%
  arrange(gender, desc(n))

print(word_frequency_list)



# 2. Comparison of Word Usage Across Genders
word_ratios <- word_frequency %>%
  group_by(word) %>%
  filter(sum(n) >= 10) %>%
  ungroup() %>%
  pivot_wider(names_from = gender, values_from = n, values_fill = 0) %>%
  mutate(
    total = male + female,
    male_ratio = (male + 1) / (total + 2),
    log_ratio = log2(male_ratio / (1 - male_ratio))
  ) %>%
  mutate(across(c(male, female), ~ ifelse(. == 0, 0.1, .))) %>%
  filter(total > 0, !is.infinite(log_ratio), !is.na(log_ratio))

ggplot(word_ratios, aes(male, female, color = abs(log_ratio), label = word)) +
  geom_abline(color = "black", linetype = "dashed") +
  geom_jitter(alpha = 0.1, size = 2.5, width = 0.3, height = 0.3) +
  geom_text_repel(aes(label = word), size = 3, max.overlaps = 15, force = 2) +
  scale_x_log10() +
  scale_y_log10() +
  scale_color_gradient(limits = c(0, 6), low = "black", high = "red") +
  labs(title = "Word Usage by Gender", x = "Male", y = "Female", color = "Log ratio") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        axis.text.y = element_text(size = 10),
        legend.position = "bottom")

ggsave("word_usage_comparison.png", width = 12, height = 8)



# 3. Favorites and Re tweets Analysis
engagement_analysis <- tweets_data %>%
  group_by(gender) %>%
  summarize(
    avg_favorites = mean(fav_number, na.rm = TRUE),
    avg_retweets = mean(retweet_count, na.rm = TRUE)
  )

engagement_long <- engagement_analysis %>%
  pivot_longer(cols = c(avg_favorites , avg_retweets), names_to = "metric", values_to = "value")

# Create a single graph showing both metrics with different y-axes
ggplot(engagement_long, aes(x = gender, y = value, fill = metric)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  geom_text(aes(label = sprintf("%.2f", value)),
            position = position_dodge(width = 0.9),
            vjust = -0.5, size = 3) +
  facet_wrap(~ metric, scales = "free_y", nrow = 2, strip.position = "top") +
  labs(title = "Average Engagement by Gender",
       x = "Gender",
       y = "Average Count",
       fill = "Metric") +
  scale_fill_manual(values = c("blue", "red"),
                    labels = c( "Average Retweets", "Average Favorites")) +  
  theme_minimal() +
  theme(legend.position = "bottom",
        strip.text = element_text(hjust = 0.5))

ggsave("engagement_by_gender_combined.png", width = 10, height = 8)


# 4. Changes in Word Use Analysis

# Create the 'month' column using the correct date column ('tweet_created')
tweets_data <- tweets_data %>%
  mutate(month = floor_date(as.Date(tweet_created, format = "%m/%d/%Y %H:%M"), unit = "month"))

# Limit tweets_data to 5000 rows
tweets_data_sample <- tweets_data %>% slice_sample(n = 5000)

# Get top words from the sample
word_frequency_sample <- tweets_data_sample %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words) %>%  # Remove stop words
  count(gender, word, sort = TRUE) %>%
  group_by(gender) %>%
  slice_max(n, n = 10) %>%  ungroup()

# Get distinct top words
top_words <- word_frequency_sample %>%
  distinct(word)

# Join tweets_words with tweets_data_sample to get the 'month' information
tweets_words_top <- tweets_data_sample %>%
  unnest_tokens(word, text) %>%
  select(gender, word, month) %>%
  filter(word %in% top_words$word)

# Summarize word trends by gender
word_trends_by_gender <- tweets_words_top %>%
  group_by(gender, word) %>%
  summarise(total_word_count = n(), .groups = 'drop')

# Plotting the trends for word usage with different colors for gender
ggplot(word_trends_by_gender, aes(x = word, y = total_word_count, color = gender)) +
  geom_point(size = 3) + geom_line(aes(group = word), color = "grey", linetype = "dashed") +  
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) + labs(title = "Word Usage Trends Across Gender",
       x = "Trending Words", y = "Total Word Count", color = "Gender") + theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8), legend.position = "bottom")

# Save the updated graph
ggsave("word_use_trends_with_gender_on_words.png", width = 15, height = 10)
