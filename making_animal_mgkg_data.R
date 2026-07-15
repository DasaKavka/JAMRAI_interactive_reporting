# make historical JIACRA datasets-----------
library(datapasta)
library(tidyr)


#2012 
JIACRA_2012 <- read_csv("Data/Consumption_data/jiacra_amc_mgkg.csv")%>%
  dplyr::select(-c(Inclusion_hosp, Total_biomass))


#2014
JIACRA_2014 <- tibble::tribble(
    ~Country,~Inclusion_hosp,~Humans_consump_tonnes,~Animals_consump_tonnes,~Total, ~Humans_biomass, ~Animals_biomass,~Total_biomass, ~Humans_mgkg, ~Animals_mgkg,
    "Austria","No",38,53,91,532,948,1480,70.9,56.3,
    "Belgium","Yes",107,266,373,700,1678,2378,153.4,158.3,
    "Bulgaria","Yes",53,33,85,453,393,846,116.0,82.9,
    "Croatia","Yes",34,31,65,265,273,539,128.4,114.8,
    "Cyprus","Yes",7,42,48,54,107,160,124.7,391.5,
    "Czech,Republic","No",65,56,121,657,703,1360,99.4,79.5,
    "Denmark","Yes",50,107,157,352,2415,2767,143.5,44.2,
    "Estonia","Yes",6,10,16,82,127,210,71.7,77.1,
    "Finland","Yes",47,11,59,341,509,850,139.2,22.3,
    "France","Yes",717,761,1479,4118,7120,11238,174.2,107.0,
    "Germany","No",287,1306,1593,5048,8749,13797,56.9,149.3,
    "Hungary","Yes",53,150,203,617,779,1396,86.6,193.1,
    "Iceland","No",2,1,3,20,116,136,101.7,5.2,
    "Ireland","Yes",45,90,134,288,1866,2154,155.6,48.0,
    "Italy","Yes",634,1432,2064,3799,3977,7776,166.9,359.9,
    "Latvia","Yes",10,6,17,125,173,298,81.6,36.7,
    "Lithuania","Yes",19,12,31,184,335,519,102.5,35.5,
    "Luxembourg","Yes",4,2,7,34,52,86,130.2,40.9,
    "Netherlands","Yes",52,214,264,1052,3135,4187,49.9,68.4,
    "Norway","Yes",45,6,50,319,1866,2185,140.1,3.1,
    "Poland","Yes",263,578,829,2376,4109,6485,110.7,140.8,
    "Portugal","Yes",76,190,266,652,942,1594,116.1,201.6,
    "Romania","Yes",226,98,323,1247,2502,3749,181.7,39.1,
    "Slovakia","Yes",47,16,64,338,248,587,140.2,65.9,
    "Slovenia","Yes",14,6,19,129,171,300,105.5,33.4,
    "Spain","No",327,2964,3291,2907,7077,9984,112.6,418.8,
    "Sweden","Yes",72,9,82,603,811,1414,119.8,11.5,
    "EU",NA,NA,NA,NA,NA,NA,NA,123.7,151.5
  ) %>%
  mutate(Year = 2014)%>%
  dplyr::select(-c(Inclusion_hosp, Total_biomass))


#2016

JIACRA_2016 <- tibble::tribble(
  ~Country,~Inclusion_hosp,~Humans_consump_tonnes,~Animals_consump_tonnes,~Total, ~Humans_biomass, ~Animals_biomass,~Total_biomass, ~Humans_mgkg, ~Animals_mgkg,
    "Austria","No",38,44,82,544,957,1501,69.2,46.1,
    "Belgium","Yes",109,240,349,707,1715,2422,153.6,140.1,
    "Bulgaria","Yes",49,61,110,447,393,840,109.1,155.3,
    "Croatia","Yes",33,27,60,262,302,564,123.8,87.9,
    "Cyprus","No",8,46,54,53,102,155,147.1,453.4,
    "Denmark","Yes",50,99,149,357,2420,2776,140.9,40.8,
    "Estonia","Yes",6,7,13,82,113,195,75.5,64.0,
    "Finland","Yes",45,10,54,343,521,864,130.0,18.6,
    "France","Yes",757,514,1271,4165,7143,11308,181.3,71.9,
    "Germany","No",339,779,1118,5136,8734,13870,64.5,89.2,
    "Greece","Yes",142,80,222,674,1258,1932,210.9,63.5,
    "Hungary","Yes",51,156,207,614,832,1446,83.1,187.1,
    "Iceland","No",2,1,3,21,120,141,108.3,4.7,
    "Ireland","Yes",48,102,150,295,1963,2258,160.9,52.1,
    "Italy","Yes",621,1213,1834,3792,4116,7907,163.7,294.8,
    "Latvia","Yes",10,5,16,123,180,303,84.1,29.9,
    "Lithuania","Yes",19,13,32,181,338,519,104.7,37.7,
    "Luxembourg","Yes",5,2,7,36,55,91,139.1,35.5,
    "Netherlands","Yes",59,182,241,1061,3446,4507,54.2,52.7,
    "Norway","Yes",45,6,51,326,1896,2222,139.4,2.9,
    "Poland","Yes",289,570,860,2373,4407,6780,122.0,129.4,
    "Portugal","Yes",80,211,291,646,1014,1660,135.9,208.0,
    "Romania","No",264,265,529,1235,3116,4351,213.7,85.1,
    "Slovakia","Yes",51,12,63,339,242,581,149.2,50.4,
    "Slovenia","Yes",13,5,18,129,178,307,97.0,30.3,
    "Spain","No",499,2725,3224,2903,7518,10420,171.6,362.5,
    "Sweden","Yes",72,10,82,616,805,1421,116.8,12.1,
    "EU",NA,4208,7706,11873,31546,61026,92571,133.2,125.6
  ) %>%
  mutate(Year = 2016)%>%
  dplyr::select(-c(Inclusion_hosp, Total_biomass))


#2018

JIACRA_2018 <-  tibble::tribble(
  ~Country,~Inclusion_hosp,~Humans_consump_tonnes,~Animals_consump_tonnes,~Total, ~Humans_biomass, ~Animals_biomass,~Total_biomass, ~Humans_mgkg, ~Animals_mgkg,
  "Austria","No",37,48,85,551,957,1509,67.1,50.1,
  "Belgium","Yes",103,195,298,712,1724,2437,145.8,113.1,
  "Bulgaria","Yes",53,48,100,441,400,841,118.6,119.6,
  "Croatia","Yes",33,20,53,257,293,550,123.7,66.8,
  "Cyprus","No",8,53,61,54,115,169,151.0,466.3,
  "Denmark","Yes",48,94,142,361,2447,2808,134.1,38.2,
  "Estonia","Yes",6,6,12,82,114,196,76.3,53.3,
  "Finland","Yes",42,9,51,345,497,841,121.1,18.7,
  "France","Yes",772,456,1228,4183,7107,11290,179.3,64.2,
  "Germany","No",350,753,1103,5175,8518,13692,65.3,88.4,
  "Greece","Yes",136,113,249,671,1244,1915,202.5,90.9,
  "Hungary","Yes",52,150,202,611,832,1443,85.3,180.6,
  "Iceland","No",3,1,3,22,116,138,129.7,4.9,
  "Ireland","Yes",48,99,146,302,2142,2444,158.9,46.0,
  "Italy","Yes",567,932,1499,3780,3819,7600,149.9,244.0,
  "Latvia","Yes",10,6,16,121,167,288,83.8,36.1,
  "Lithuania","Yes",24,11,34,176,324,499,134.4,33.1,
  "Luxembourg","Yes",7,2,9,38,55,92,177.1,33.6,
  "Malta","Yes",4,2,6,30,14,44,124.3,150.9,
  "Netherlands","Yes",60,184,244,1074,3201,4275,54.3,57.5,
  "Norway","Yes",44,6,50,331,1928,2258,134.1,2.9,
  "Poland","Yes",335,782,1117,2374,4673,7046,141.2,167.4,
  "Portugal","Yes",81,192,273,643,1028,1671,138.3,186.6,
  "Romania","No",280,231,511,1221,2788,4009,227.9,82.7,
  "Slovakia","Yes",40,12,52,340,247,586,118.1,49.3,
  "Slovenia","Yes",14,8,22,129,180,309,107.1,43.2,
  "Spain","Yes",551,1724,2275,2916,7865,10782,187.0,219.2,
  "Sweden","Yes",71,10,81,633,783,1415,112.1,12.5,
  "EU",NA,4263,6358,10622,31713,60792,92505,133.3,104.6
) %>%
  mutate(Year = 2018)%>%
  dplyr::select(-c(Inclusion_hosp, Total_biomass))

#2021

JIACRA_2021 <-  tibble::tribble(
  ~Country,~Humans_consump_tonnes,~Animals_consump_tonnes,~Total, ~Humans_biomass, ~Animals_biomass, ~Humans_mgkg, ~Animals_mgkg,
  "Austria",45,39,84,558,945,79.8,41.3,
  "Belgium",83,169,252,722,1770,115.2,95.3,
  "Bulgaria",54,49,102,432,391,124.2,124.5,
  "Croatia",27,21,48,243,331,113.1,62.7,
  "Cyprus",8,45,53,56,152,139.9,296.5,
  "Czechia",94,35,129,657,709,142.8,50.0,
  "Denmark",45,82,127,365,2452,123.5,33.4,
  "Estonia",5,5,11,83,114,65.7,46.6,
  "Finland",32,8,40,346,492,92.6,17.0,
  "France",678,349,1027,4232,6758,160.1,51.7,
  "Germany",181,591,772,4582,8071,39.5,73.2,
  "Greece",99,120,219,667,1100,148.4,108.8,
  "Hungary",40,132,171,608,846,65.1,155.6,
  "Iceland",2,1,3,23,145,101.9,3.6,
  "Ireland",39,93,133,313,2196,126.1,42.4,
  "Italy",479,662,1141,3702,3813,129.4,173.5,
  "Latvia",8,4,12,118,153,68.8,25.5,
  "Lithuania",16,6,22,175,297,94.2,20.3,
  "Luxembourg",4,1,5,36,54,99.4,27.1,
  "Malta",4,2,5,32,15,113.2,110.5,
  "Netherlands",45,147,192,1013,3092,44.3,47.6,
  "Norway",44,5,49,337,2197,130.3,2.5,
  "Poland",248,775,1023,2365,4417,104.7,175.5,
  "Portugal",63,159,222,616,1063,101.8,149.9,
  "Romania",187,174,361,1200,2943,155.8,59.0,
  "Slovakia",29,10,39,341,230,85.5,41.7,
  "Slovenia",11,6,17,132,184,82.4,31.8,
  "Spain",433,1296,1729,2958,8245,146.5,157.2,
  "Sweden",58,9,67,649,788,90.1,10.9,
  "EU",3061,4994,8056,27564,53961,125.0,92.6
) %>%
  mutate(Year = 2021) 

JIACRA_historic <- rbind(JIACRA_2012,JIACRA_2014,JIACRA_2016,JIACRA_2018,JIACRA_2021) %>%
  dplyr::select(Year,Country,Animals_mgkg)



# 2023, 2024

Esuavet_2023_2024 <- read_csv("Data/Consumption_data/esuavet_food_animal_sales_2023_2024.csv") %>%
  dplyr::select(year,country,sales_mgkg)

names(Esuavet_2023_2024) <- c("Year","Country","Animals_mgkg")

animal_mg_kg <- rbind(JIACRA_historic,Esuavet_2023_2024)

write_csv(animal_mg_kg, "Data/Animal_mg_kg.csv")

