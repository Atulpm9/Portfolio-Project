-- Select all the record from table 1: CovidDeaths - EDA

select *
from CovidDeaths
order by 3,4

-- Select the data to analyse from table 1: CovidDeaths - EDA

select location,date,total_cases, new_Cases, total_deaths, population
from CovidDeaths
order by 1,2

-- Understand total cases vs total deaths as a % for each day based on location and date

select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS case_to_death_ratio
from CovidDeaths
order by 1,2

-- Understand the same data for a specific location using a where clause

select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS case_to_death_ratio
from CovidDeaths
where location = 'India'
--where location like '%States%' | Using wildcards
order by 1,2 desc

-- Undertanding the total cases vs population
-- what percetnage of the population is getting infected each day

select location, date, total_cases, population, (total_cases/population)*100 AS infected_percentage
from CovidDeaths
--where location = 'India'
order by 1,2

-- What country has the highest infection rate

select location,max(total_cases) As Infection_Peak, population, (max(total_cases)/population)*100 As Infection_Rate
from CovidDeaths
group by location,population
order by 4 desc

-- What country has the highest death 

select location, max(total_deaths) AS Death_peak
from CovidDeaths
group by location
order by 2 desc

-- Casting total deaths as integer to as the data definition for this column is varchar()

select location, max(cast(total_deaths as int)) AS Death_peak
from CovidDeaths
group by location
order by 2 desc

-- we are now able to see continents as part of the location, this is an invalid view. After inspection some of the continent data was added incorrectly to location column

select * from CovidDeaths
where location = 'Asia'
order by 3,4

-- we will be using a not null clause to eleminate these for further analysis and create a new view to use it for further analysis

create view Updated_CovidDeaths AS
select * 
from CovidDeaths
where continent is not null

select * from Updated_CovidDeaths

-- Updating the previous statement with the new view created from the OG dataset

select location, max(cast(total_deaths as int)) AS Death_peak
from Updated_CovidDeaths
group by location
order by 2 desc

-- List of countries with more than 100K deaths recorded - Using an having clause

select location, max(cast(total_deaths as int)) AS Death_peak
from Updated_CovidDeaths
group by location
having max(cast(total_deaths as int)) >= 100000
order by 2 desc

-- Identifying the list of countries with the highest infection rate & death rate

select location, population, 
max(total_cases) As Infection_max, 
max(cast(total_deaths as int)) AS Death_max, 
( max(total_cases)/population)*100 AS Infection_Rate, 
max(cast(total_deaths as int))/ max(total_cases)*100 AS Death_Rate
from Updated_CovidDeaths
group by location, population
order by 6 desc

-- Breaking things down by continent

select continent, max(cast(total_deaths as int)) AS Death_peak
from Updated_CovidDeaths
group by continent
order by 2 desc

-- Showing the continent with the highest death count - Using the top clause

select top 1 continent, max(cast(total_deaths as int)) AS Death_peak
from Updated_CovidDeaths
group by continent
order by Death_peak desc

-- Global Numbers

-- Death rate and Infection percentage

-- Inorder to find the global infection rate we need to first get the overall population
-- Using a subquery we will now be avle to arrive at the desired result using the following code

	select sum(population) As Total_Population ,sum(cases) AS Global_cases, sum(Death) As Golbal_Deaths, 
	(sum(cases)/sum(population))*100 AS Global_Infection_Rate, (sum(Death)/sum(cases))*100 As Global_Death_Rate
	from
	(
		select location, 
		max(population) As Population,
		max(total_cases) AS cases,
		max(cast(total_deaths as int)) AS Death, 
		(max(total_cases)/max(population))*100 As Infection_Rate, 
		(max(cast(total_deaths as int))/max(total_cases))*100 AS Death_Rate
		from Updated_CovidDeaths
		group by location
		) as pop_cal_table

-- FINDINGS: Globally 1.95% of the overall population got infected out of which 2% died.

-- VACCINATIONS TABLE for Analysis

select * from CovidVaccinations
order by 3,4

-- Joining both the tables together using location and date

select * 
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date

-- Looking for total population that got vaccinated.

select CD.continent, CD.location, CD.date, population, new_vaccinations
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null
order by 2,3

-- Looking for total population that got vaccinated for a specific country

select CD.continent, CD.location, CD.date, population, new_vaccinations
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null
where CD.location = 'India'
order by 2,3

-- Looking for total population that got vaccinated and adding a view of total vaccinations right next to it based on the location.
-- This displays the number of vaccinations administered during the day for a location and also total vaccinations administered for that location

select CD.continent, CD.location, CD.date, population, CV.new_vaccinations, SUM(cast(CV.new_vaccinations as int)) OVER(PARTITION BY CD.location) AS Total_Vac_per_country
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null
order by 2,3

-- The following code adds a new column that calculates the rolling total for each day per country

select CD.continent, CD.location, CD.date, population, CV.new_vaccinations, 
SUM(cast(CV.new_vaccinations as int)) OVER(PARTITION BY CD.location order by CD.location, CD.date) AS Rolling_Total_vac
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null
order by 2,3

-- Calculate rolling vaccinated percentage using a CTE

with PopvsVac 
as
(
select CD.continent, CD.location, CD.date, population, CV.new_vaccinations, 
SUM(cast(CV.new_vaccinations as int)) OVER(PARTITION BY CD.location order by CD.location, CD.date) AS Rolling_Total_vac
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null
)
select * , (Rolling_Total_vac)/population * 100 AS Rolling_Vac_percentage
from PopvsVac
where location = 'India'


-- Calculate rolling vaccinated percentage using a Temp Table

-- Creating the temp table

DROP TABLE IF exists #PopVac
CREATE TABLE #PopVac
(
    Continent nvarchar(255),
    Location nvarchar(255),
    Date datetime,
    Population numeric,
    New_vaccinations numeric,
    Rolling_Total_vac numeric
);

-- Insert into the temp table using an output

INSERT INTO #PopVac (Continent, Location, Date, Population, New_vaccinations, Rolling_Total_vac)
SELECT
    CD.continent,
    CD.location,
    CD.date,
    CD.population,
    CV.new_vaccinations,
    SUM(CONVERT(int, CV.new_vaccinations)) OVER (PARTITION BY CD.location ORDER BY CD.location, CD.date) AS Rolling_Total_vac
FROM
    CovidDeaths AS CD
JOIN
    CovidVaccinations AS CV ON CD.location = CV.location AND CD.date = CV.date
--WHERE CD.continent IS NOT NULL;

-- Selecting from the temp table and calculating Rolling_Vac_percentage
SELECT
    *,
    (Rolling_Total_vac / Population) * 100 AS Rolling_Vac_percentage
FROM
    #PopVac;

-- Creating a view for a new joined table without null values

create or alter view PopVac as
select CD.continent, CD.location, CD.date, population, CV.new_vaccinations, sum(convert(int, CV.new_vaccinations)) over(partition by cd.location, cd.date) As Rolling_Total_per_location
from CovidDeaths AS CD
join CovidVaccinations AS CV
ON CD.location = CV.location 
AND CD.date = CV.date
AND CD.continent is not null

select * from popvac

-- Creating a function to get the total cases of a specific country

create or alter function tot_cases(@location varchar(255))
returns int
	as
		begin
			declare @tc int;
				select @tc=max(total_cases) -- oe @tc = sum(new_cases)
				from Updated_CovidDeaths
				where location = @location;

			return @tc;
		end;

-- Executing the custom fuction

select dbo.tot_cases('India');

-- Creating a procedure to display the total death % for a specific country

create or alter procedure TDP( @location varchar(255))
as
	begin
		select location, (max(total_cases)/max(cast(total_deaths as int)))*100 AS Death_percentage
		from Updated_CovidDeaths
		group by location
		having location = @location;
	end;

-- Executing the stored procedure

execute TDP 'India'