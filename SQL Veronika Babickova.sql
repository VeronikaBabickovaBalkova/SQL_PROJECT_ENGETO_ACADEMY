-- TABULKA  pro zodpovezeni vyzkumnych otazek 1-4 --

-- pomocny view 1 --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_primary_final_cpy AS
	SELECT 
		round (avg (value)) AS mzda_prumerna,
		payroll_year ,
		cpib.name AS odvetvi
	FROM czechia_payroll AS cpy
		LEFT JOIN czechia_payroll_industry_branch cpib 
			ON cpib.code=cpy.industry_branch_code 
		LEFT JOIN czechia_payroll_value_type cpvt 
			ON cpvt.code=cpy.value_type_code 
	WHERE cpvt.code = '5958' AND cpib.name IS NOT NULL 
	GROUP BY payroll_year , odvetvi;

-- pomocny view 2 --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_primary_final_cpr AS
	SELECT 
		round (avg (value)) AS potravina_prum_cena,
		cpc.name AS potravina_nazev,
		YEAR(date_from) AS rok
	FROM czechia_price AS cpr
	LEFT JOIN czechia_price_category cpc 
		ON cpr.category_code = cpc.code 
	GROUP BY rok, potravina_nazev;

-- zakladni vysledna tabulka pro vyzkumne otazky 1-4 --

CREATE OR REPLACE TABLE t_veronika_babickovabalkova_project_SQL_primary_final AS 
	SELECT *
	FROM v_veronika_babickovabalkova_project_SQL_primary_final_cpr 
	LEFT JOIN v_veronika_babickovabalkova_project_SQL_primary_final_cpy
		ON v_veronika_babickovabalkova_project_SQL_primary_final_cpr.rok=v_veronika_babickovabalkova_project_SQL_primary_final_cpy.payroll_year ;
	
/*
 * Vyzkumna otazka č.1
 * Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
 * vysledny script pro otazku c. 1
 */
	
SELECT
	rok,
	odvetvi,
	mzda_prumerna 
FROM t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf 
GROUP BY rok, odvetvi
ORDER BY odvetvi , rok;

/*
 * Vyzkumna otazka č.2
 * Kolik je možne si koupit litru mleka a kilogramu chleba za prvni a posledni srovnatelne obdobi v dostupnych datech cen a mezd?
 */
	
-- pomocny view 1 --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_primary_final_2potravina AS 
SELECT 
	rok,
	potravina_nazev ,
	round (avg(potravina_prum_cena))
FROM t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf 
WHERE potravina_nazev IN ('Chléb konzumní kmínový', 'Mléko polotučné pasterované') AND rok IN ('2006', '2018')
GROUP BY potravina_nazev, rok;

-- pomocny view 2 --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_primary_final_2mzda AS 
SELECT 
	rok,
	round(avg(mzda_prumerna))
FROM t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf 
WHERE rok IN ('2006', '2018')
GROUP BY rok ;

-- vysledny script pro otazku c. 2 --

SELECT
	vvbpspfm.rok,
	vvbpspfm.`round(avg(mzda_prumerna))` ,
	vvbpspfp.rok ,
	vvbpspfp.potravina_nazev ,
	vvbpspfp.`round (avg(potravina_prum_cena))`,
	round(vvbpspfm.`round(avg(mzda_prumerna))` / vvbpspfp.`round (avg(potravina_prum_cena))`) AS KolikMohuKoupit
FROM v_veronika_babickovabalkova_project_SQL_primary_final_2mzda vvbpspfm 
LEFT JOIN v_veronika_babickovabalkova_project_SQL_primary_final_2potravina vvbpspfp 
ON vvbpspfm.rok = vvbpspfp.rok 
ORDER  BY potravina_nazev, vvbpspfm .rok;


/*
 * Vyzkumna otazka č.3
 * Ktera kategorie potravin zdrazuje nejpomaleji (je u ni nejnizsi percentualni mezirocni narust)?
 * vysledny script pro otazku c.3
 */

WITH zdrazPOT AS ( 
SELECT 		
		rok,
		potravina_nazev ,
		round (potravina_prum_cena / lead(potravina_prum_cena,-1) OVER (ORDER BY potravina_nazev, rok),2) AS zdrazeniVproc
	FROM t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf
	WHERE rok <> 2006 AND rok <> 2018
GROUP BY rok, potravina_nazev 
ORDER BY potravina_nazev , rok
)
SELECT 
	potravina_nazev ,
	sum (zdrazeniVproc)
FROM 
zdrazPOT
GROUP BY potravina_nazev 
ORDER BY sum (zdrazeniVproc);


/*
 * Vyzkumna otazka č.4
 * Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
 * vysledny script pro otazku c.4
 */

WITH comparison_mzdy_ceny AS (
	SELECT
		rok,
		potravina_prum_cena/ lead(potravina_prum_cena,-1) OVER (ORDER BY potravina_nazev, rok) AS narust_cen,
		mzda_prumerna / lead  (mzda_prumerna,-1) OVER (ORDER BY rok) AS narust_mzdy
	from t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf
	GROUP BY rok 
	)
SELECT 
	rok,
	CASE
		WHEN narust_cen - narust_mzdy > 0.1 THEN 'mezirocni narust cen potravin ku mzdam o 10% a vyse' ELSE 0
	END AS total
FROM comparison_mzdy_ceny;


/*
 * Vyzkumna otazka č.5
 * Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji 
 * v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo náslujícím roce výraznějším růstem?
 */

-- základní tabulka --

CREATE OR REPLACE TABLE t_veronika_babickovabalkova_project_sql_secondary_final
SELECT 
	e.country,
	e.`year` ,
	e.GDP ,
	e.gini ,
	e.population
FROM economies e 
RIGHT JOIN countries c 
	ON e.country =c.country
WHERE region_in_world LIKE '% Europe';

-- pomocny view 1 na cz --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_sql_secondary_cz AS
SELECT
	country,
	year,
	gdp
FROM t_veronika_babickovabalkova_project_sql_secondary_final
WHERE country = 'Czech republic';

-- pomocny view 2 prumer cen a mezd --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_secondary_mzdyAceny AS
SELECT
	round (avg (potravina_prum_cena),2) AS PruCenPotr,
	round (avg (mzda_prumerna),0) AS PruMzda,
	rok 
FROM t_veronika_babickovabalkova_project_SQL_primary_final tvbpspf
GROUP BY rok;

-- join obou views --

CREATE OR REPLACE VIEW v_veronika_babickovabalkova_project_SQL_secondary_gdpmzdyceny AS
SELECT
	PruCenPotr / lead (PruCenPotr,-1) OVER (ORDER BY rok) AS CenPotrMeziro,
	PruMzda / lead (PruMzda,-1) OVER (ORDER BY rok) AS MzdyMeziro,
	GDP / lead (GDP, -1) OVER (ORDER BY rok) AS GDPMeziro,
	rok
FROM v_veronika_babickovabalkova_project_SQL_secondary_mzdyAceny vvbpssm 
JOIN v_veronika_babickovabalkova_project_sql_secondary_cz vvbpssc 
ON vvbpssm.rok = vvbpssc.`year` ;

-- zjisteni referencnich hodnot --

SELECT
	avg (CenPotrMeziro) AS CPM,
	avg (MzdyMeziro),
	avg (GDPMeziro)
FROM v_veronika_babickovabalkova_project_SQL_secondary_gdpmzdyceny vvbpssg;

-- vlastni skript --

SELECT 
	rok,
CASE 
	WHEN GDPMeziro >1.02127 THEN 'vyrazny vzrust GDP' ELSE 0
	END AS vlivGDP,
CASE 
	WHEN CenPotrMeziro >1.02878 THEN 'vyrazny vzrust cen' ELSE 0
	END AS ceny,
CASE 
		WHEN MzdyMeziro  >1.03852 THEN 'vyrazny vzrust mezd' ELSE 0
	END AS mzdy	
FROM v_veronika_babickovabalkova_project_SQL_secondary_gdpmzdyceny vvbpssg 
ORDER BY vlivGDP desc;

SELECT 
 	country ,
	 `year` ,
	 GDP 
FROM t_veronika_babickovabalkova_project_sql_secondary_final tvbpssf 
WHERE country LIKE 'Czech Republic';
