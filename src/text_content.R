# === text_content.R — editorial / methodology HTML text blocks ===

Welcome_text <- "
Here you can add text to welcome readers and outline the context/link to reports, e.g. for Belgium:
<br/><br/>
Antimicrobial agents are vital for treating and preventing the spread of diseases.  However, pathogens like bacteria and fungi can develop resistance to these drugs, especially in the face of antimicrobial overuse and misuse. 
<br/><br/>
A key step in the fight against antimicrobial resistance is the careful monitoring of drug usage and resistance patterns. This surveillance is key to both developing and monitoring the effect of interventions such as optimal treatment guidelines and infection prevention and control programs.
<br/><br/>
In Belgium, antimicrobial consumption (AMC) and the emergence of resistance (AMR) is monitored in various settings including human medicine, food-producing animals, and the food supply chain. Additionally, data is collected on the sales of antimicrobial products for all animals and for non-medical use (for example in agriculture), as well as the detection of antimicrobial residues in the environment. As the results from these diverse programs are reported separately, it can be challenging to gain a clear overview of the trends in AMR and AMC across sectors in Belgium.
<br/><br/>
The BELMAP report aims to provide this overview - comprehensively summarising results and trends from existing surveillance programs from all sectors and directing readers to the detailed sector-specific reporting. Cross-sectoral collaboration also allows the BELMAP network to identify potential gaps and make recommendations for
improving future monitoring.
<br/><br/>
Visit the <a href='https://bit.ly/BELMAP2025'>interactive BELMAP report</a> to explore the most recent data on AMR and AMC in Belgium.
<br/><br/>
"


# keep methodologies for data, remove other texts

method_general <- "<b>Statistical analysis and reporting</b>
<br/><br/>
Plots were generated in R (version R- 4.2.1) using the ggplot2 package.
For each yearly observed percentage of samples testing resistant (number of resistant/total sample size * 100) or where
noted number of resistant cases per 1000 patient days), bars represent
the observed value. We used a Log-linear Poisson regression analysis to
evaluate the effect of time (year) on the number of instances
antimicrobial resistance occurred. An exposure variable (offset option
in R) was included in the model to indicate the number of times
resistance could have occurred in theory, i.e. sample size. In case of
overdispersion, quasi-Poisson or negative binomial analyses were
performed. The best fit regression is depicted by a line graph, with
ribbons representing the 95% confidence intervals, calculated based on
the link function of the glm (fit data +/- 2*Standard Error based on
link scale). Pearson (normally
distributed data) and Spearman correlation tests were performed to
explore the relation between the consumption of antimicrobial agents and
time.
<br/><br/>
Please note all trend analyses were performed using the <b>entire dataset</b>, thus while the axes scales of figures can be adjusted, changing the years of data visualised, the trend shown refers to the trend across the entire dataset. All statistical analyses were conducted in R and all code and data
are available on the <a href='https://github.com/BELMAP/BELMAP2023_analysis'>[BELMAP Github]</a>, along with the publication of all data from the report in the appendix (available to download on the Contributor page).
<br/><br/>
Symbols are included on figures to represent results of statistical
analyses:<br/><br/>"

Introduction_text3 <- "Results are indicated as *,** and *** for results with p-values
0.05<p<0.01, 0.01<p<0.001 and p<0.001, respectively. To enable clearer visualisation of trends, the scale of figures can be adapted using the 'Flexible scale' button. For resistance data from veterinary samples, standardised description of resistance levels will be applied, consistent with the <a href='https://www.efsa.europa.eu/en/efsajournal/pub/4036'>[EFSA criteria]</a>: rare= <0.1%, very low= 0.1% to 1.0%, low= 1% to 10.0%, moderate= 10.0% to 20.0%, high: 20.0% to 50.0%, very high: 50.0% to 70.0%, extremely high:> 70.0%. These terms are applied to all antimicrobials. However, the significance of a given level of resistance will depend on the antimicrobial in question and its importance in human and veterinary medicine."

Methodology_human_data_collection <-"
The epidemiological monitoring of AMR in humans in Europe is coordinated by :
<br/><br/>
• the European (EU) Antimicrobial Resistance Surveillance Network for
Belgium <a href='https://www.ecdc.europa.eu/en/about-us/networks/disease-networks-and-laboratory-networks/ears-net-data'>[('EARS-Net')].<br/>
<br/><br/>
<b>EARS-Net</b> <br/>
<a href='https://www.ecdc.europa.eu/en/about-us/networks/disease-networks-and-laboratory-networks/ears-net-data'>[EARS-Net]</a>
is the main EU epidemiological surveillance system for AMR, and its data
serve as important indicators on the occurrence and spread of AMR in
<a href='https://www.ecdc.europa.eu/en/%20surveillance-atlas-infectious-diseases'>[European countries]</a>.
On a yearly basis, this monitoring system collects and reports data from
European countries on AMR against relevant antimicrobials within
commonly occurring pathogens isolated from <b>clinical invasive samples
(blood and cerebrospinal fluid (CSF))</b> in humans. EARS-Net collects
such data on seven bacterial pathogens commonly causing infections in
humans: <i>Escherichia coli</i>, <i>K. pneumoniae</i>, <i>P. aeruginosa</i>, <i>Acinetobacter</i>
species, <i>S. pneumoniae</i>, <i>S. aureus</i>, <i>E. faecalis</i> and <i>E. faecium</i>.
EU member states are requested to participate in EARS-Net by EU
recommendation (Council Recommendation, 2009/C 151/01), with
<b>participation voluntary</b> for laboratories.
<br/>
In Belgium, national data is collected and submitted to the EU by the
'Healthcare-associated infections and antimicrobial resistance service'
of Sciensano (NSIH), through the <a href='https://www.sciensano.be/nl/projecten/europese-antimicrobiele-resistentie-surveillance-belgie'>['EARS-BE surveillance']</a>.
"



food_prod_methods <- "This dashboard uses AMR data coordinated by <a href='https://www.efsa.europa.eu/en/microstrategy/dashboard-antimicrobial-resistance'>['EFSA']</a>. Data from commensal <i>E. coli</i> isolated from healthy animals as a general indicator for resistance among food-producing animals. <i>E. coli</i> is an indicator bacterium that can be frequently isolated from all animal species. Resistance levels within <i>E. coli</i> reflect the magnitude of selective pressure exerted by antibiotics in the population, and can be used as an indicator of emergence and change in AMR in the population. Additionally, MRSA is monitored in different animal categories to map both the prevalence of this resistant zoonotic bacterium and its level of resistance to other antibiotics.
<br/><br/>
For commensal <i>E. coli</i> monitoring in Belgium, the Federal Agency for the Safety of the Food Chain (FASFC) has collected samples of caecal content at the slaughterhouse and fresh faeces at farm  annually since 2011 as part of a nationwide surveillance program. The following categories of food-producing animals are included: beef cattle (meat production, faeces sampled at the farm level), and veal calves, broiler chickens and fattening pigs sampled at the slaughterhouse. The sampling and isolation of indicator <i>E. coli</i> strains are performed according to standardized technical instructions, details of which are available in the <a href='https://favv-afsca.be/nl/antibioticaresistentie-resultaten#sciensano'>[reports of FASFC]</a>.
<br/><br/>
<i>E. coli</i> bacteria are tested for susceptibility to ciprofloxacin, cefotaxime, colistin and 12 other antibiotics, as determined by European legislation (2013/652/EU and 2020/1729). Since 2014, all the isolates showing resistance to a third generation cephalosporin are considered potential beta-lactamase producing <i>E. coli</i>, and are analyzed in detail for their beta-lactamase activity. For more details please see the <a href='https://favv-afsca.be/nl/antibioticaresistentie-resultaten#sciensano'>[Sciensano-FASFC reports.]</a>
<br/><br/>
The surveillance of MRSA follows a 3-year cycle and includes farm samples (pooled nasal swabs) from the poultry, cattle, or pig sector, depending on the year. AMR testing of MRSA strains is detailed in the reports available on the FASFC website. The method used to isolate MRSA strains from pooled nasal swabs changed in 2022 to the so-called 1-S isolation method according to the <a href='https://www.eurl-ar.eu/CustomerData/Files/Folders/21-protocols/430_mrsa-protocol-final-19-06-2018.pdf'>[EURL-AR protocol version from 2018]</a>, in which the second enrichment step with cefoxitin and aztreonam applied for the previous monitoring years (the so-called 2-S isolation method)  is excluded.   The confirmed MRSA isolates are spa-typed by retrieving, from the whole-genome sequencing (WGS), the repetitive region of the <i>spa</i> gene encoding for the staphylococcal protein A, and categorized as livestock associated (LA) MRSA if they are associated to the <i>S. aureus</i> clonal complex CC398 through WGS.
<br/><br/>"

AMR_text_outline <- "Here you can add Text describing the findings - this can reactive to what is selected"

AMR_fig_text_outline <- "Here you can add Text describing the figure - this can reactive to what is selected"


AMC_text_outline <- "Here you can add Text describing the findings - this can reactive to what is selected"

AMC_fig_text_outline <- "Here you can add Text describing the figure - this can reactive to what is selected"
