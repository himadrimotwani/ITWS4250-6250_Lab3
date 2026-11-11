-- ============================================================================
-- ITWS 4250/6250 Database Applications and Systems, Fall 2026
-- Lab 3: Knowledge Graph Implementation with Neo4j
-- Part 5 - Question 5: Relational Schema & Recursive SQL Query
-- Student: Himadri Motwani
-- RCS Email: motwah@rpi.edu
-- Level: 6000
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RELATIONAL SCHEMA DESIGN
-- ----------------------------------------------------------------------------

-- Table 1: Region hierarchy (Adjacency List Model)
-- admin_level: 0 = Country, 1 = State, 2 = City
CREATE TABLE Region (
    region_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    admin_level INT NOT NULL CHECK (admin_level IN (0, 1, 2)),
    parent_id VARCHAR(20) REFERENCES Region(region_id)
);

-- Table 2: Disease entity table
CREATE TABLE Disease (
    disease_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    pathogen VARCHAR(100),
    vector VARCHAR(100)
);

-- Table 3: CaseReport relationship / fact table
CREATE TABLE CaseReport (
    report_id SERIAL PRIMARY KEY,
    region_id VARCHAR(20) NOT NULL REFERENCES Region(region_id),
    disease_id VARCHAR(20) NOT NULL REFERENCES Disease(disease_id),
    date_reported DATE NOT NULL,
    case_count INT NOT NULL CHECK (case_count >= 0)
);


-- ----------------------------------------------------------------------------
-- 2. SAMPLE DATA INSERTION (FOR VERIFICATION)
-- ----------------------------------------------------------------------------

-- Level 0: Countries
INSERT INTO Region (region_id, name, admin_level, parent_id) VALUES 
('IN', 'India', 0, NULL),
('BR', 'Brazil', 0, NULL),
('NG', 'Nigeria', 0, NULL);

-- Level 1: States
INSERT INTO Region (region_id, name, admin_level, parent_id) VALUES 
('IN-TN', 'Tamil Nadu', 1, 'IN'),
('BR-SP', 'São Paulo', 1, 'BR'),
('BR-RJ', 'Rio de Janeiro', 1, 'BR'),
('NG-LA', 'Lagos', 1, 'NG');

-- Level 2: Cities
INSERT INTO Region (region_id, name, admin_level, parent_id) VALUES 
('IN-TN-CHE', 'Chennai', 2, 'IN-TN'),
('IN-TN-CBE', 'Coimbatore', 2, 'IN-TN'),
('BR-SP-SAO', 'São Paulo', 2, 'BR-SP'),
('BR-RJ-RIO', 'Rio de Janeiro', 2, 'BR-RJ'),
('NG-LA-IKJ', 'Ikeja', 2, 'NG-LA');

-- Diseases
INSERT INTO Disease (disease_id, name, pathogen, vector) VALUES 
('D1', 'Malaria', 'Plasmodium parasite', 'Anopheles mosquito'),
('D2', 'Dengue', 'Dengue virus', 'Aedes mosquito'),
('D3', 'Chikungunya', 'Chikungunya virus', 'Aedes mosquito'),
('D4', 'Zika', 'Zika virus', 'Aedes mosquito');

-- Case Reports
INSERT INTO CaseReport (region_id, disease_id, date_reported, case_count) VALUES 
('IN-TN-CHE', 'D2', '2026-09-30', 500),
('IN-TN-CHE', 'D1', '2026-09-30', 180),
('IN-TN-CBE', 'D1', '2026-09-30', 250),
('BR-SP-SAO', 'D3', '2026-09-30', 120),
('BR-SP-SAO', 'D2', '2026-09-30', 650),
('BR-RJ-RIO', 'D2', '2026-09-30', 800),
('NG-LA-IKJ', 'D1', '2026-09-30', 1500),
('NG-LA-IKJ', 'D2', '2026-09-30', 90);


-- ----------------------------------------------------------------------------
-- 3. RECURSIVE SQL QUERY (ANSWERING QUESTION 1)
-- ----------------------------------------------------------------------------
-- Using WITH RECURSIVE to traverse down the Region hierarchy from Country (admin_level = 0)
-- to all descendant regions (States, Cities), then aggregating case counts per Country.

WITH RECURSIVE RegionHierarchy AS (
    -- Anchor member: Select all top-level countries (admin_level = 0)
    SELECT 
        region_id AS country_id,
        name AS country_name,
        region_id AS current_region_id
    FROM Region
    WHERE admin_level = 0

    UNION ALL

    -- Recursive member: Traverse down from parent region to child regions
    SELECT 
        rh.country_id,
        rh.country_name,
        child.region_id AS current_region_id
    FROM RegionHierarchy rh
    JOIN Region child ON child.parent_id = rh.current_region_id
)
SELECT 
    rh.country_name AS country,
    SUM(cr.case_count) AS total_cases
FROM RegionHierarchy rh
JOIN CaseReport cr ON cr.region_id = rh.current_region_id
GROUP BY rh.country_id, rh.country_name
ORDER BY total_cases DESC;


-- ----------------------------------------------------------------------------
-- 4. COMPARISON: SQL (RELATIONAL) VS CYPHER (GRAPH)
-- ----------------------------------------------------------------------------
/*
Comparison Analysis (4-6 sentences):

1. Readability and Conciseness:
   The Cypher query is significantly more readable and declarative because it represents path traversals 
   using ASCII-art pattern matching `(country:Country)<-[:IS_PART_OF*]-(city:City)` rather than the complex, 
   verbose CTE scaffolding required by ANSI SQL `WITH RECURSIVE`.

2. Expressiveness of Variable-Length Paths:
   In Cypher, variable-length relationship patterns `[:IS_PART_OF*1..3]` treat edges as first-class citizens 
   with index-free adjacency, allowing queries to effortlessly express transitive closures without explicit joins.

3. Resilience to Schema / Hierarchy Evolution:
   If a new intermediate administrative level (such as 'District' at admin_level 2, pushing 'City' to admin_level 3) 
   is introduced, the Cypher query requires ZERO changes because `[:IS_PART_OF*]` naturally traverses any depth. 
   While the recursive SQL CTE would also continue to work, any standard (non-recursive) relational query would 
   require rewriting all multi-table JOIN clauses.

4. Performance and Cognitive Load:
   Relational databases must evaluate recursive CTEs using iterative table scans and join ladders, whereas graph 
   databases traverse pointer chains directly in memory. For complex network and hierarchical queries, graph databases 
   dramatically lower both developer cognitive load and query execution complexity.
*/
