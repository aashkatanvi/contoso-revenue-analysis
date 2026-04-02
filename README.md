# Contoso Revenue Analysis: Revenue Decline Driven by Weak Core Channels and Inefficient Online Growth

> End-to-end business analysis using SQL, Power BI, and Excel to diagnose drivers of revenue decline and evaluate growth sustainability.

## 📊 Business Problem

Is Contoso’s revenue decline driven by weakening core channels, or is online growth masking deeper inefficiencies?

---

## 🎯 Objectives

- Identify discount dependency across channels and categories  
- Analyze whether growth is driven by volume or value  
- Evaluate relationship between discounting and profitability  
- Assess sustainability of current growth strategy  

---

## 🛠️ Tools Used

- SQL (PostgreSQL)  
- Power BI  
- Excel  

---

## 🧠 Approach

- Combined online and offline sales data using SQL  
- Analyzed transaction-level metrics to evaluate AOV and discount dependency  
- Compared margin trends before and after discount across channels  

---

## 📷 Dashboard Preview

![Dashboard](dashboard.png)

---

## 🔍 Key Insights

- Revenue declined ~9.3%, driven primarily by weakening core channels  
- Online growth is volume-driven but inefficient:
  - Transactions increased significantly  
  - AOV dropped ~27%  
  - Margins declined despite stable discount rates  
- Discount dependency remains high (~66%)  
- Core channels are declining sharply, outweighing limited gains from online growth  

---

## 💡 Conclusion

The business is shifting toward a volume-driven online growth model that increases transactions but reduces value per sale.

This trend is structurally unsustainable and highlights a key business risk — continued reliance on such growth may erode profitability further.

---

## 📁 Repository Structure

- `analysis.sql` → SQL queries for all business questions  
- `contoso-revenue-analysis.pbix` → Power BI dashboard  
- `supporting-analysis.xlsx` → Excel validation & pivots  
- `dashboard.png` → Dashboard preview  
