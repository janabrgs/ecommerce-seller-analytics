## Project Overview

This project analyzes e-commerce marketplace data from the Olist dataset with the goal of identifying high-value sellers early and understanding which marketing, sales, and business factors are associated with strong seller performance.

The project covers the full workflow from data preparation and SQL-based feature engineering to exploratory data analysis, machine learning, and business dashboarding.

## Objectives

- Identify high-value sellers based on revenue performance
- Understand which factors influence seller success
- Build a reproducible end-to-end analytics workflow
- Translate analytical results into business insights through a dashboard

## Dataset

The project uses e-commerce marketplace data based on the Olist dataset. It includes information on:

- Sellers
- Marketing leads
- Lead origin and lead type
- Lead behavior profiles
- Orders and revenue

These data sources are integrated in PostgreSQL using a warehouse-style structure.

## Tech Stack

- PostgreSQL
- SQL
- Python
- Pandas
- NumPy
- scikit-learn
- Jupyter Notebook
- Power BI
- Power Query
- Visual Studio Code

## Project Structure

```text
ecommerce-seller-analytics/
├── data/                # Project data notes / raw data placeholder
├── sql/                 # SQL scripts for warehouse setup and feature engineering
├── notebooks/           # Jupyter notebook for EDA and machine learning
├── powerbi/             # Power BI dashboard
├── README.md

Data Engineering

The data pipeline is structured in PostgreSQL using a simple warehouse approach with raw and mart schemas.

Key steps include:

Cleaning and transforming raw data
Joining marketing, seller, and revenue data
Building analytical tables for downstream analysis and modeling

Created tables include:

seller_revenue
ml_seller_features
ml_model_dataset
seller_analytics
Feature Engineering

Important engineered features include:

Revenue aggregated at seller level
time_to_close_days
Marketing channel (origin)
Lead type
Lead behavior profile
Target variable high_value_seller based on top 20% revenue sellers
Exploratory Data Analysis

The EDA focuses on questions such as:

How is revenue distributed across sellers?
Is there a long-tail revenue pattern?
Which marketing channels bring the most successful sellers?
Which business segments generate the highest revenue?
How do lead type and lead behavior affect seller success?
What is the relationship between sales cycle duration and revenue?
Machine Learning

The machine learning goal is to classify sellers into:

High-Value Seller
Non-High-Value Seller
Model
Random Forest Classifier
Workflow
Data preparation
Feature encoding with one-hot encoding
Train-test split
Model training
Model evaluation
Feature importance analysis
Results

Main findings from the model:

Accuracy: approximately 82%
Strong classification performance for low-value sellers
Lower recall for high-value sellers due to class imbalance
ROC-AUC indicates moderate discrimination ability
Key Drivers of Seller Success

The most important predictive factors were:

Time to close
Lead type
Marketing channel
Lead behavior profile
Dashboard

A Power BI dashboard was built to translate the analysis into business insights.

Included analyses:

Total revenue and seller distribution
High-value seller rate
Revenue by business segment
Performance by marketing channel
Lead behavior impact
Relationship between sales cycle and revenue
Long-tail revenue distribution

Available interactive filters:

Marketing channel
Business segment
Lead type
Key Learnings

This project demonstrates:

End-to-end analytics workflow design
SQL-based data engineering
Feature engineering for machine learning
Business-oriented model interpretation
Dashboard development for stakeholder communication
Notes
The trained model is not versioned in this repository
The model can be retrained at any time using the notebook
The focus of this project is on interpretability, business relevance, and the end-to-end process
