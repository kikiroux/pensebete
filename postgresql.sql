select count (job_name) from horsys.gt_jobq, horsys.gt_ini_fic where horsys.gt_ini_fic.i_file = horsys.gt_jobq.sbm_parameter and horsys.gt_ini_fic.i_cle ~* 'ligne_un' and dem_usr = '-ERM' and exe_statut = 1 


select substring(j.job_name, 5, 12) as DateVieuxProcess, case substring(j.job_name, 1, 4) when 'DSAC' then 'Accept' when 'DSRF' then 'Refus' when 'DSAS' then 'Astreinte' end as Process, substring(j.sbm_parameter, 4, 3) as Nature, j.societe, j.job_name
from horsys.gt_jobq j, horsys.gt_ini_fic i
where i.i_file = j.sbm_parameter
and i.i_cle ~* 'ligne_un' 
and dem_usr = '-ERM'
and exe_statut = 1



--------------------- activity --------------------------
select * from pg_stat_activity where current_query <> '<IDLE>';
---------------------------------------------------------
----------------------- SIZE ---------------------------- 
--------------------------------------------------------- 
-- renvoie la taille disk d'une base de donnée (equivalent à un du -s -h sur le repertoire de la base (select oid, datname from pg_database);
SELECT pg_database_size('nom_de_la_base'); -- 
SELECT pg_size_pretty(pg_database_size('MPCLI099')); -- la même au format humain
SELECT pg_database_size(oid) -- la meme avec un oid au lieu du nom

--renvoie la taille d'un schema 
SELECT SUM(pg_total_relation_size(quote_ident('horsys') || '.' || quote_ident(tablename)))::BIGINT FROM pg_tables WHERE schemaname = 'horsys'



-- renvoie la taille disk d'une table avec ses index et ses toasted data
pg_total_relation_size = pg_table_size + pg_indexes_size
SELECT pg_size_pretty(pg_total_relation_size('rbulps')) as table_total_size;
SELECT pg_size_pretty(pg_total_relation_size(oid)) as table_total_size;

-- renvoie le chemein et le nombre de pages de 8Ko d'une relation (attention il faut qu'un vaccum analyse au minimum ait été déjà fait.

SELECT pg_relation_filepath(oid), relpages FROM pg_class WHERE relname = 'rbulps';

-- renvoie la taille disk d'une table sans les index (prends en compte les toast data, la fsm, la visibility map)
SELECT pg_size_pretty(pg_table_size('rbulps'));


-- renvoie la taille disk d'une table sans les index et sans les toasted data
SELECT pg_size_pretty(pg_relation_size('rbulps')) as table_data_size;
SELECT pg_size_pretty(pg_relation_size(oid)) as table_data_size;

-- renvoie la taille des index d'une table
select pg_total_relation_size(c.oid)- pg_relation_size(c.oid) - (CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END) AS index_size from pg_class c;
select pg_total_relation_size('rbulps')- pg_relation_size('rbulps') - (select CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END  from pg_class c where c.relname='rbulps') AS index_size from pg_class c where c.relname='rbulps';
select pg_indexes_size('rbulps');
SELECT c2.relname, c2.relpages FROM pg_class c, pg_class c2, pg_index i WHERE c.relname = 'rbulps' AND  c.oid = i.indrelid AND  c2.oid = i.indexrelid ORDER BY c2.relname;




-- renvoie la taille disk d'un index
-- attention lorsqu'on cree une table sans index de notre fait, postgres doit créer des index cachés, par conséquent
-- la somme des index d'une table n'est pas égale à la taille des index renvoyés par taille_totale_relation - taille relation - taille des toasts
-- preuve : create table matable as select * from rbulps; 
select pg_relation_size('pk_rbulps'));
select pg_size_pretty(pg_relation_size('pk_rbulps'));

--renvoie la taille totale des index d'une base :

select pg_size_pretty ((select sum(T.size)::bigint from (select pg_total_relation_size(oid) as size from pg_class where relkind='i')T)) as total_index_size;

-- taille des tables toast
SELECT a, n, pg_relation_size(t), pg_size_pretty(pg_relation_size(t))
FROM   (SELECT c.relname, c.reltoastrelid, d.relname
        FROM   pg_class c JOIN pg_class d ON c.reltoastrelid = d.oid
       ) AS x(a, t, n)
WHERE  t > 0 AND pg_relation_size(t) > 0
ORDER BY 3 DESC;

ou

SELECT relname, relpages
FROM pg_class,
     (SELECT reltoastrelid
      FROM pg_class
      WHERE relname = 'indus.ids_zonepg') AS ss
WHERE oid = ss.reltoastrelid OR
      oid = (SELECT reltoastidxid
             FROM pg_class
             WHERE oid = ss.reltoastrelid)
ORDER BY relname;


-- recap des tailles 

SELECT
    c.relname AS name,
    c.reltuples::bigint AS tuples,
    pg_relation_size(c.oid) AS table_size,
    pg_total_relation_size(c.oid)-pg_relation_size(c.oid) - (CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END) AS index_size,
    CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END AS toast_size,
    pg_total_relation_size(c.oid) AS total_size
FROM 
    pg_catalog.pg_class c
JOIN 
    pg_catalog.pg_roles r ON r.oid = c.relowner
LEFT JOIN 
    pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE 
    c.relkind = 'r'
AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
-- AND pg_catalog.pg_table_is_visible(c.oid) -- si on ne veut que les tables qui sont ds le search_path courant
ORDER BY total_size DESC;


-- trouver la plus grosse table au sein d'une base (en nbre de page c'est à dire en nombre de bloc (par défaut 8ko)
-- ne tient pas compte des index et des toasts donc faux
SELECT relname, relpages FROM pg_class ORDER BY relpages DESC;


-- Calculer la taille des index de toute la base
select pg_size_pretty((select sum(relpages)*8*1024 from pg_class where relkind= 'i'));
ou 
select sum(T.size) from (select oid,pg_total_relation_size(oid) as size from pg_class where relkind='i')T;
ou 
select pg_size_pretty ((select sum(T.size)::bigint from (select pg_total_relation_size(oid) as size from pg_class where relkind='i')T)) as total_index_size;


-- utiliser des vues pour se simplifier la vie
CREATE OR REPLACE VIEW view_relations_size AS 
SELECT
    c.relname AS name,
    c.reltuples::bigint AS tuples,
    pg_relation_size(c.oid) AS table_size,
    pg_total_relation_size(c.oid)-pg_relation_size(c.oid) - (CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END) AS index_size,
    CASE WHEN c.reltoastrelid <> 0 THEN pg_relation_size(c.reltoastrelid) ELSE 0 END AS toast_size,
    pg_total_relation_size(c.oid) AS total_size
FROM 
    pg_catalog.pg_class c
JOIN 
    pg_catalog.pg_roles r ON r.oid = c.relowner
LEFT JOIN 
    pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE 
    c.relkind = 'r'
AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
-- AND pg_catalog.pg_table_is_visible(c.oid) -- si on ne veut que les tables qui sont ds le search_path courant
ORDER BY total_size DESC;

select * from view_relations_size; 
CREATE VIEW view_relations_size_pretty AS
SELECT
    name,
    tuples,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(index_size) AS index_size,
    pg_size_pretty(toast_size) AS toast_size,
    pg_size_pretty(total_size) AS total_size
FROM view_relations_size;
select * from view_relations_size_pretty
---------------- FIN SIZE -------------------------


-----------------BLOAT : FRAGMENTATION ------------

-- le otta represente la taille théorique des données(exprimées en pages) en fonction du nombre de tuples de la table
-- le tbloat represente le rapport qu'il y a entre la colonne pages et la colonne otta. Par conséquent plus le otta s'éloigne de 1 (un) 
-- plus la taille réeelle des données s'écarte de la valeur théorique et donc plus la fragmentation est importante.Un otta = 2 signifie donc 
-- le nombre de page réelles utlisées par la table est 2 fois plus grande que la taille théorique. Pour une table ce n'est pas super grave en soi surtout si 
-- le vacuum analyse passe bien tous les jours et que le max_fsm_pages est bien paramétré. En effet les trous seront marqués comme libres
-- et reutilisés lors de prochains insert ou update. un vacuum full peut (mais pas toujours ??) récuperer la place perdue. En ce qui concernee
-- les index le ibloat peut être plus génant puisque l'intéret d'un index et de pouvoir accéder plus vide au données : il ne faut pas que pour 
-- lire l'index lui-même on soit obliger de faire bcp de lecture dues à des pages d'index pleines de trous. Dans ce cas un reindex table peut
-- être le bienvenu mais attention cette opération pose un verrou exclusif sur la table, il vaut donc mieux faire cela en dehors des fortes
-- activités de la base.
-- conclusion :
--    vacuum analyse verbose suffisant (car le full perturbe trop les bases à cause des locks exclusifs)
--    si une table devient vraiement trop fragmenté dans le temps, faire un vacuum full sur cette table
--    le vacuum n'est interessant que sur les tables où il y a bcp d'update et/ou de delete
--    reindex régulier soit sur toute la base soit sur les index dont le ibloat est trop grand.
--    bien paramétrer le max_fsm_pages (lire les logs de vacuum analyse verbose pour savoir si c'est ok)


SELECT
  current_database(), schemaname, tablename, /*reltuples::bigint, relpages::bigint, otta,*/
  ROUND(CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
  pg_size_pretty(CASE WHEN relpages < otta THEN 0::bigint ELSE (bs*(sml.relpages-otta))::bigint END) AS prettywastedbytes,
  iname, /*ituples::bigint, ipages::bigint, iotta,*/
  ROUND(CASE WHEN iotta=0 OR ipages=0 THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,
  pg_size_pretty(CASE WHEN ipages < iotta THEN 0::bigint ELSE (bs*(ipages-iotta))::bigint END) AS prettywastedibytes
FROM (
  SELECT
    schemaname, tablename, cc.reltuples, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM (
    SELECT
      ma,bs,schemaname,tablename,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        schemaname, tablename, hdr, ma, bs,
        SUM((1-null_frac)*avg_width) AS datawidth,
        MAX(null_frac) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
        ) AS nullhdr
      FROM pg_stats s, (
        SELECT
          (SELECT current_setting('block_size')::numeric) AS bs,
          CASE WHEN substring(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  JOIN pg_class cc ON cc.relname = rs.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml
ORDER BY wastedbytes DESC

-- ce qui suit est directement tiré de check_postgres.pl
SELECT
          current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,
          ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
          CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,
          CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
          CASE WHEN relpages < otta THEN '0 bytes'::text ELSE (bs*(relpages-otta))::bigint || ' bytes' END AS wastedsize,
          iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,
          ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,
          CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,
          CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,
          CASE WHEN ipages < iotta THEN '0 bytes' ELSE (bs*(ipages-iotta))::bigint || ' bytes' END AS wastedisize
        FROM (
          SELECT
            schemaname, tablename, cc.reltuples, cc.relpages, bs,
            CEIL((cc.reltuples*((datahdr+ma-
              (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta,
            COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
            COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
          FROM (
            SELECT
              ma,bs,schemaname,tablename,
              (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
              (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
            FROM (
              SELECT
                schemaname, tablename, hdr, ma, bs,
                SUM((1-null_frac)*avg_width) AS datawidth,
                MAX(null_frac) AS maxfracsum,
                hdr+(
                  SELECT 1+count(*)/8
                  FROM pg_stats s2
                  WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
                ) AS nullhdr
              FROM pg_stats s, (
                SELECT
                  (SELECT 8192) AS bs,
                  CASE WHEN substring(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
                  CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
                FROM (SELECT version() AS v) AS foo
              ) AS constants
              GROUP BY 1,2,3,4,5
            ) AS foo
          ) AS rs
          JOIN pg_class cc ON cc.relname = rs.tablename
          JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
          LEFT JOIN pg_index i ON indrelid = cc.oid
          LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
        ) AS sml
         WHERE sml.relpages - otta > 0 OR ipages - iotta > 10 ORDER BY wastedbytes DESC LIMIT 10;



--- test de bloat
drop table if exists croux ;
CREATE TABLE croux
(
  no_client integer NOT NULL,
  
  CONSTRAINT pk_croux PRIMARY KEY (no_client)
  
);

insert into croux select * from generate_series(1,1000000); -- ici la table n'apparaît pas ds la requete de bloat
vacuum  analyse verbose croux; -- ici la table apparaît ds la requete de bloat (tups=1000000,pages=5406,otta=4406,tbloat=1.2,ipages=2745,iotta=2448,ibloat=1.1
delete from croux where no_client <= 500000; -- ici la ligne reste inchangée avec tups toujours à 1000000 !!!
vacuum analyse verbose croux; -- ici tups=500000,pages=5406,otta=2203 !!, tbloat=2.5 !! ipages = 2745,iotta=1224 !!! , ibloat = 2.2 !!!
-- en fait ce qu'il s'est passé : postgres a marqué les enregistrements détruits comme étant libre. Il n'a pas compacté. 
-- donc pages identique, par contre tups a changé (diminué par deux), donc otta a changé à la baisse et tbloat a changé à la hausse
-- meme constat pour ipages,iotta et ibloat (un index n'est jamais qu'une table)
-- reindex table croux;-- ipages = 1374, iotta=1224,ibloat=1.1 : cela revient à un compactage des index
insert into croux select * from generate_series(1,500000); -- pas de changement car pas encore de vacuum
vacuum analyse verbose croux; -- on revient aux valeurs initiales avec un tbloat=1.2 : Normal car on a reutilisé la place libre.Le ibloat passe 
-- à 1.6 à cause du reindex qu'on a fait avant. si on ne fait pas le reindex alors ibloat = 1.1
delete from croux where no_client <= 500000; -- on recommence
vacuum  analyse verbose croux;-- tbloat=2.5 et ibloat=2.2 : normal.  wastedbytes : 26238976 wastedibytes : 34004992
vacuum full analyse verbose croux; -- tbloat=1.2 ibloat=4.4 (faudra recrer les index si on veut faire baisser le ibloat)
reindex table croux; -- tbloat=1.2, ibloat = 1.1 !!!!

------------------------ LOCK ------------------------------
SELECT 
    waiting.locktype           AS waiting_locktype,
    waiting.relation::regclass AS waiting_table,
    waiting_stm.current_query  AS waiting_query,
    waiting.mode               AS waiting_mode,
    waiting.pid                AS waiting_pid,
    other.locktype             AS other_locktype,
    other.relation::regclass   AS other_table,
    other_stm.current_query    AS other_query,
    other.mode                 AS other_mode,
    other.pid                  AS other_pid,
    other.granted              AS other_granted
FROM
    pg_catalog.pg_locks AS waiting
JOIN
    pg_catalog.pg_stat_activity AS waiting_stm
    ON (
        waiting_stm.procpid = waiting.pid
    )
JOIN
    pg_catalog.pg_locks AS other
    ON (
        (
            waiting."database" = other."database"
        AND waiting.relation  = other.relation
        )
        OR waiting.transactionid = other.transactionid
    )
JOIN
    pg_catalog.pg_stat_activity AS other_stm
    ON (
        other_stm.procpid = other.pid
    )
WHERE
    NOT waiting.granted
AND
    waiting.pid <> other.pid;

-- la requete qui suit n'est pas terrible. Ne remonte pas la même chose que la requete qui précede
SELECT bl.pid                 AS blocked_pid,
         a.usename              AS blocked_user,
         ka.current_query       AS blocking_statement,
         now() - ka.query_start AS blocking_duration,
         kl.pid                 AS blocking_pid,
         ka.usename             AS blocking_user,
         a.current_query        AS blocked_statement,
         now() - a.query_start  AS blocked_duration
  FROM  pg_catalog.pg_locks         bl
   JOIN pg_catalog.pg_stat_activity a  ON a.procpid = bl.pid
   JOIN pg_catalog.pg_locks         kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
   JOIN pg_catalog.pg_stat_activity ka ON ka.procpid = kl.pid
  WHERE NOT bl.granted;    

------------------------------------- SHARED BUFFER ------------------------------
select blks_hit*1.0 / ( blks_hit + blks_read ) * 100 as percent from pg_stat_database where datname=current_database(); -- plus le taux est proche de 100 mieux c'est  
-- ce qui suit necessite le module pg_buffercache.sql et attention verrouille le cache : attention donc au performance  
-- create extension pg_buffercache;
SELECT count(*) * 100 / ( select count(*) from pg_buffercache) AS "% utilise du cache" FROM pg_buffercache WHERE relfilenode IS NOT NULL; 
-- donne le nombre de page dans le shared_buffer par relation. la 1ere du resultset est donc la table qui utilise le plus le shared_buffer
select c.relname,count(*) as buffers from pg_class c inner join pg_buffercache b on b.relfilenode=c.relfilenode inner join pg_database d on (b.reldatabase=d.oid and d.datname=current_database()) group by c.relname order by 2 DESC limit 10;
-- hit ratio
SELECT 
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit)  as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM 
  pg_statio_user_tables;

SELECT ROUND((blks_hit::FLOAT/(blks_read+blks_hit+1)*100)::NUMERIC,2) FROM pg_stat_database WHERE datname=current_database();

-- Index Cache Hit Rate : doit être le plus proche de 1
SELECT 
  sum(idx_blks_read) as idx_read,
  sum(idx_blks_hit)  as idx_hit,
  (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
FROM 
  pg_statio_user_indexes;

-- liste les tables qui ont un parcours sequentiel (il manque donc un index. pour des tables dont le nbre de tuple est > 10000 il vaut mieux avoir un index
SELECT 
  relname, 
  100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used, 
  n_live_tup rows_in_table
FROM 
  pg_stat_user_tables
WHERE 
    seq_scan + idx_scan > 0 
ORDER BY 
  n_live_tup DESC;
---------------------  work_mem et temporary file

explain analyze select count(*) from (select random() as i from generate_series(1,1000) order by i) as x;

template1=# explain analyze select count(*) from (select random() as i from generate_series(1,1000) order by i) as x;
-[ RECORD 1 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN | Aggregate  (cost=77.33..77.34 rows=1 width=0) (actual time=7.384..7.384 rows=1 loops=1)
-[ RECORD 2 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |   ->  Sort  (cost=62.33..64.83 rows=1000 width=0) (actual time=7.218..7.295 rows=1000 loops=1)
-[ RECORD 3 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         Sort Key: (random())
-[ RECORD 4 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         Sort Method: quicksort  Memory: 71kB
-[ RECORD 5 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         ->  Function Scan on generate_series  (cost=0.00..12.50 rows=1000 width=0) (actual time=6.270..6.515 rows=1000 loops=1)
-[ RECORD 6 ]-------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN | Total runtime: 7.422 ms

-- on voit que la requete a utilisé 71 kB de mémoire pour le tri.
explain analyze select count(*) from (select random() as i from generate_series(1,20000) order by i) as x;
template1=# explain analyze select count(*) from (select random() as i from generate_series(1,20000) order by i) as x;
-[ RECORD 1 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN | Aggregate  (cost=77.33..77.34 rows=1 width=0) (actual time=30.867..30.867 rows=1 loops=1)
-[ RECORD 2 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |   ->  Sort  (cost=62.33..64.83 rows=1000 width=0) (actual time=25.944..29.145 rows=20000 loops=1)
-[ RECORD 3 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         Sort Key: (random())
-[ RECORD 4 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         Sort Method: external merge  Disk: 352kB
-[ RECORD 5 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN |         ->  Function Scan on generate_series  (cost=0.00..12.50 rows=1000 width=0) (actual time=2.784..6.499 rows=20000 loops=1)
-[ RECORD 6 ]--------------------------------------------------------------------------------------------------------------------------------
QUERY PLAN | Total runtime: 31.087 ms

-- on voit que ce coup-ci le tri s'est fait sur un fichier temporaire (external merge)


------------------------------------- DROITS -------------------------------------
alter role postgres NOSUPERUSER;
alter role postgres SUPERUSER;
revoke connect on database "MPCLI" from public;
revoke connect on database "MPCLI" from postgres;
grant connect on database "MPCLI" to public;
grant connect on database "MPCLI" to postgres;

------------------------------------- FIN ----------------------------------------

-- postgresql.conf : 8.4 ---------------------------------------------------------
-- wal_buffers : 1 Mo <= wal_buffers <= 8 Mo . une bonne valeur est 4 Mo pour ne plus y revenir
-- work_mem    : pour chaque process , attention à ne pas mettre trop (max_connection) : sert au tris et au hachage. Si un processus a besoin
--               de plus, les données déjà hachées , triées seront écrites sur disque avant de réutilisée de la mémoire 
-- maintenance_work_mem : sert au opération de maintenance : vacuum,création d'index,création de clés étrangères. C'est une mémoire comme le 
--                        workmem c'est à dire individuelle et allouable à chaque process. En pratique, on peut mettre une valeur bien plus
--                        importante que pour work_mem car rarissime que plus de 2 utilisateurs fasse des opérations de maintenance simultanément.
-- shared_buffers       : mémoire partagée, cache disque des fichiers de données et des fichers de transaction
-- checkpoint_segments  : indique au  bout de combien de journaux de transaction écrits, un checkpoint survient (un checkpoint est une opération
--                      : qui consiste à écrire dans les fichiers de données (sinon tout est en mémoire ou dans les journaux de transaction)
--                      : Mettre au minimum 10. Si on fait confiance au système de stockage en dessous et à la plateforme, on peut encore augmenter.
--                      : le risque est d'avoir bcp de fichiers de transaction non écrit ds les fichiers de données au moment où un crash arrive.
--                      : cela obligera postgres à rejouer bcp de fichiers de transaction au redemarrage.Cela augmente aussi la place disque.
-- checkpoint_timeout   : en secondes, permet d'indiquer au bout de combien de temps un checkpoint se produit. Cela permet de faire quand même
--                      : un checkpoint si checkpoint_segments n'est pas atteint (base peu solicitée). Il faut bien écrire les données à un moment
--                      : quand même.
-- checkpoint_completion_target : Comme on repousse avec l'option checkpoint_segments, le moment où on va faire un checkpoint, ce dernier lorsqu'il
--                              : se produira aura bcp de données à écrire. On peut donc avoir un pic d'écriture (bloquant en gros le reste
--                              : de l'activité). ce paramétre permet de diluer dans le temps les écritures (évitant le pic). Exemple si il s'écoule
--                              : 4 minutes entre 2 checkpoints, on va indiquer en pourcentage le temps d'écriture entre 2 checkpoints. On va donc
--                              : diluer (répartir) les écritures sur ces 4 minutes.Une bonne valeur est 0,9. (90%)
-- effective_cache_size         : taille du cache disque du système d'exploitation. Cela permet au plannificateur d'estimer la probabilité
--                              : pour qu'une table ou un index soit en cache.Plus la valeur de ce paramètre est importante plus les parcours d'index
--                              : sont valorisés
-- random_page_cost             : cout d'accès à une page aléatoire sur disque. Pour les disques récents et rapide mettre 2 peut apporter un plus trés
--                              : conséquent car là aussi cela valorisera les parcours d'index.
-- max_connections              : ne jamais dépasser 1000. Penser au delà à utiliser un pooler
-- lc_messages                  : mettre C pour faire des recherches sur internet et/ou pour avoir l'aide des developpeurs.
-- log_destination              : syslog pour en tirer toutes les possibilités
-- archive_mode                 : on (dans ce cas il faut que archive_command soit renseigné)
-- archive_command              : commande à lancer dès qu'un fichier de transaction sera prêt à être archivé. %p chemin complet du fichier à archiver
--                              : %f nom du fichier de transaction une fois archivé. Il faut IMPERATIVEMENT que cette commande renvoie 0 quand 
--                              : le journal a été archivé avec succés et autre chose si erreur. 
-- archive_timeout              : si l'activité du serveur n'est pas énorme, mais qu'on souhaite malgré tout archiver les journaux de transaction
--                              : assez frequemment, ce paramètre force postgres change de journal de transaction une fois ce delai écoulé.
--                              : du coup, l'ancien est prêt à être archivé.Mais il ne le sera pas forcément immédiatement, il faut qu'un checkpoint
--                              : ait eu lieu.Avec un checkpoint_timeout bien superieur à archive_timeout, l'archivage se fera plutôt à chaque
--                              : checpoint_timeout plutôt qu'à chaque archive_timeout.

 
-- idle in transaction

SELECT procpid
FROM
(
    SELECT DISTINCT age(now(), query_start) AS age, procpid
    FROM pg_stat_activity, pg_locks
    WHERE pg_locks.pid = pg_stat_activity.procpid
) AS foo
WHERE age > '30 seconds'
ORDER BY age DESC
LIMIT 1;

psql -h localhost -U postgres -t -d test_database -f trxTimeOut.sql | xargs kill



-- pg_buffer-cache doit etre installé pour ce qui suit


-- 1 : renvoie le top 10 des tables qui sont dans le shared en nombre de block
SELECT
  c.relname,
  count(*) AS buffers
FROM pg_class c 
  INNER JOIN pg_buffercache b
    ON b.relfilenode=c.relfilenode 
  INNER JOIN pg_database d
    ON (b.reldatabase=d.oid AND d.datname=current_database())
GROUP BY c.relname
ORDER BY 2 DESC
LIMIT 10;

--2 donne le top 10 des tables en donnant la quantité de donnée ds le shared, le % de buffer que cela represente, et le % de la taille de table que cela represente

SELECT 
  c.relname,
  pg_size_pretty(count(*) * 8192) as buffered,
  round(100.0 * count(*) / 
    (SELECT setting FROM pg_settings WHERE name='shared_buffers')::integer,1) 
    AS buffers_percent,
  round(100.0 * count(*) * 8192 / pg_table_size(c.oid),1) 
    AS percent_of_relation
FROM pg_class c
  INNER JOIN pg_buffercache b 
    ON b.relfilenode = c.relfilenode
  INNER JOIN pg_database d
    ON (b.reldatabase = d.oid AND d.datname = current_database())
GROUP BY c.oid,c.relname
ORDER BY 3 DESC
LIMIT 50;


3 -- donne la popularité (usage_count) des buffers d'une table. Compte les blocs de chaque relation par leur compteur d'utilisation

SELECT
  c.relname, count(*) AS buffers,usagecount
FROM pg_class c
  INNER JOIN pg_buffercache b 
    ON b.relfilenode = c.relfilenode
  INNER JOIN pg_database d
    ON (b.reldatabase = d.oid AND d.datname = current_database())
GROUP BY c.relname,usagecount
ORDER BY c.relname,usagecount;

-- 4 determine si l'acces au tables est realisé par des parcours  sequentiels ou par des parcours d'index 
SELECT
  schemaname,
  relname,
  seq_scan,
  idx_scan,
  cast(idx_scan AS numeric) / (idx_scan + seq_scan) AS idx_scan_pct
FROM pg_stat_user_tables
WHERE (idx_scan + seq_scan)>0
ORDER BY idx_scan_pct desc;


-- supprimer (terminer des process)
select pg_cancel_backend(16967);
select pg_terminate_backend(16967)

-- recharger la conf
select pg_reload_conf()

-- savoir depuis quand postgres est démarré
SELECT pg_postmaster_start_time();
select now() - pg_postmaster_start_time();

--genere  mot de passe hache md5 - 
select 'md5'||md5('password'||'user')
select 'md5'||md5('007@crPRD'||'srhdbacro') -- prod md5df995d2567b82399b7a21f2b3b0b6dd3
select 'md5'||md5('007@crRCT'||'srhdbacro') -- rct md5a83e1dbafbf447e1ec27d63f0b510fb4
select 'md5'||md5('mai@crPRD'||'srhdbacro') -- prod "md504f32d3a144f1cd49f3d7a3e37cc691b"
select 'md5'||md5('mai@crRCT'||'srhdbacro') -- rct "md56418c00419ddee11defc8820779b120c"


-- renvoie l'ensemble des currently active backend process IDs (backendid) (from 1 to the number of active backend processes)
select * from pg_stat_get_backend_idset()

-- renvoie la liste des requetes en cours pour chaque backendid
SELECT s.backendid,pg_stat_get_backend_pid(s.backendid) AS procpid, pg_stat_get_backend_activity(s.backendid) AS current_query  FROM (SELECT pg_stat_get_backend_idset() AS backendid) AS s;
-- renvoie le PID Linux de notre backend
select pg_backend_pid()

select * from pg_stat_activity;

alter role toto valid until 'infinity';

-- journaux de transaction 
select pg_current_xlog_location() ; -- renvoie la position de la prochaine écriture des le journal de transaction ex : 0/17508A0
select pg_xlogfile_name_offset(pg_current_xlog_location()); -- fournit le nom du fichier et l'offset dans le fichier de log  ex: (000000010000000000000001,7670056)
select pg_xlogfile_name(pg_current_xlog_location()); -- renvoie le nom du WAL courant, ex : 000000010000000000000030
-- (2+checkpoint_completion_target) * checkpoint_segments + 1 : c'est le nombre de journaux de transaction que postgres utilise en temps normal. 
-- dans le pire des cas, si postgres a 3 fois plus de  de journaux de transaction que checkpoint_segments, postgres les supprimera au lieu de les renommer.

-- statistique sur les checkpoints
psql -c "select pg_stat_reset();" -- remet à zero toutes les stats de l'instance
-- remet à zero les stat du bg_writer à faire à chaque fois qu'on lance l'instance postgres si on veut avoir quelque chose de cohérent avec la requête qui suit
psql -c "select pg_stat_reset_shared('bgwriter');" 
-- affiche le nombre total de checkpoint et le temps entre chaque checkpoint (necessite d'avoir fait select pg_stat_reset_shared('bgwriter'); dès le démarrage de l'instance
SELECT
total_checkpoints,
seconds_since_start / total_checkpoints / 60 AS minutes_between_checkpoints
FROM
(SELECT
EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time())) AS seconds_since_start,
(checkpoints_timed+checkpoints_req) AS total_checkpoints
FROM pg_stat_bgwriter
) AS sub;
-- affiche les stat du bgwriter, notamment le nombre de checkpoint déclanchés (soit manuellement soit par checkpoint_segment = checkpoint_req) soit par checkpoint_timeout (checkpoint_timed)
select * from pg_stat_bgwriter; 
-- affiche les checkpoints déclenchés par checkpoint_segment 
select checkpoints_req from pg_stat_bgwriter; 
-- affiche les checkpoints déclenchés par checkpoint_timeout 
select checkpoints_timed from pg_stat_bgwriter; 
select * from pg_stat_database;


-- vacuum et autovacuum
  -- se connecter sur la base de données pour voir qu'elles sont les tables éligibles pour l'autovacuum selon la regle (https://www.postgresql.org/docs/current/static/routine-vacuuming.html#AUTOVACUUM
  -- vacuum threshold = vacuum base threshold + vacuum scale factor * number of tuples avec :
  --    vacuum base threshold = autovacuum_vacuum_threshold 
  --    vacuum scale factor =  autovacuum_vacuum_scale_factor
  --    number of tuples = pg_class.reltuples (The number of obsolete tuples is obtained from the statistics collector) 
  -- If the relfrozenxid value of the table is more than vacuum_freeze_table_age transactions old, an aggressive vacuum is performed to freeze old tuples and advance relfrozenxid; otherwise, only pages that have been modified since the last vacuum are scanned.

  WITH vbt AS (SELECT setting AS autovacuum_vacuum_threshold FROM 
pg_settings WHERE name = 'autovacuum_vacuum_threshold')
    , vsf AS (SELECT setting AS autovacuum_vacuum_scale_factor FROM 
pg_settings WHERE name = 'autovacuum_vacuum_scale_factor')
    , fma AS (SELECT setting AS autovacuum_freeze_max_age FROM 
pg_settings WHERE name = 'autovacuum_freeze_max_age')
    , sto AS (select opt_oid, split_part(setting, '=', 1) as param, 
split_part(setting, '=', 2) as value from (select oid opt_oid, 
unnest(reloptions) setting from pg_class) opt)
SELECT
    '"'||ns.nspname||'"."'||c.relname||'"' as relation
    , pg_size_pretty(pg_table_size(c.oid)) as table_size
    , age(relfrozenxid) as xid_age
    , coalesce(cfma.value::float, autovacuum_freeze_max_age::float) 
autovacuum_freeze_max_age
    , (coalesce(cvbt.value::float, autovacuum_vacuum_threshold::float) 
+ coalesce(cvsf.value::float,autovacuum_vacuum_scale_factor::float) * 
pg_table_size(c.oid)) as autovacuum_vacuum_tuples
    , n_dead_tup as dead_tuples
FROM pg_class c join pg_namespace ns on ns.oid = c.relnamespace
join pg_stat_all_tables stat on stat.relid = c.oid
join vbt on (1=1) join vsf on (1=1) join fma on (1=1)
left join sto cvbt on cvbt.param = 'autovacuum_vacuum_threshold' and 
c.oid = cvbt.opt_oid
left join sto cvsf on cvsf.param = 'autovacuum_vacuum_scale_factor' and 
c.oid = cvsf.opt_oid
left join sto cfma on cfma.param = 'autovacuum_freeze_max_age' and 
c.oid = cfma.opt_oid
WHERE c.relkind = 'r' and nspname <> 'pg_catalog'
and (
    age(relfrozenxid) >= coalesce(cfma.value::float, 
autovacuum_freeze_max_age::float)
    or
    coalesce(cvbt.value::float, autovacuum_vacuum_threshold::float) + 
coalesce(cvsf.value::float,autovacuum_vacuum_scale_factor::float) * 
pg_table_size(c.oid) <= n_dead_tup
   -- or 1 = 1
)
ORDER BY age(relfrozenxid) DESC LIMIT 50;

-- Utilisez la requête suivante pour déterminer si autovacuum est en cours d'exécution, et pendant combien de temps il a été en cours d'exécution.
-- pour PG 9.1 remplacer pid par proc_pid et query par current_query
SELECT datname, usename, pid, waiting, current_timestamp - xact_start 
AS xact_runtime, query
FROM pg_stat_activity WHERE upper(query) like '%VACUUM%' ORDER BY 
xact_start;

-- connaitre la liste des tables qui ont un parametre spécifiques (par exemple , vis à vis de l'autovacuum)
select relname, reloptions from pg_class where reloptions is not null;


select * from pg_logdir_ls();

-- sort les tables qui sont éligibles à l'autovacuum 
WITH rel_set AS
(
    SELECT
        oid,
        CASE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)::BIGINT
        END AS rel_av_vac_threshold,
        CASE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_scale_factor=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_scale_factor=', 2), ',', 1)::NUMERIC
        END AS rel_av_vac_scale_factor
    FROM pg_class
) 
SELECT
    PSUT.relname,
    to_char(PSUT.last_vacuum, 'YYYY-MM-DD HH24:MI')     AS last_vacuum,
    to_char(PSUT.last_autovacuum, 'YYYY-MM-DD HH24:MI') AS last_autovacuum,
    to_char(C.reltuples, '9G999G999G999')               AS n_tup,
    to_char(PSUT.n_dead_tup, '9G999G999G999')           AS dead_tup,
    to_char(coalesce(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + coalesce(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples, '9G999G999G999') AS av_threshold,
    CASE
        WHEN (coalesce(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + coalesce(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples) < PSUT.n_dead_tup
        THEN '*'
    ELSE ''
    END AS expect_av
FROM
    pg_stat_user_tables PSUT
    JOIN pg_class C
        ON PSUT.relid = C.oid
    JOIN rel_set RS
        ON PSUT.relid = RS.oid
ORDER BY C.reltuples DESC;



-- exemple de user read only pour Pichet
select 'md5'||md5('iA*36~*td:8U'||'pichet_ro'); -- md50b8d56f17e21226cf55bd90d1d5dee94 definition du mot de passe.
create role pichet_ro NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN CONNECTION LIMIT 5 encrypted password 'md50b8d56f17e21226cf55bd90d1d5dee94'; -- 5 connexions max
GRANT USAGE ON SCHEMA dwhouse TO pichet_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA dwhouse TO pichet_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA dwhouse TO pichet_ro;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dwhouse TO pichet_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE srhbatch IN SCHEMA dwhouse GRANT SELECT ON TABLES TO pichet_ro; -- pour les tables qui seront créées après 
ALTER DEFAULT PRIVILEGES FOR ROLE srhbatch IN SCHEMA dwhouse GRANT SELECT ON SEQUENCES TO pichet_ro; -- pour les sequences qui seront créées après 
ALTER DEFAULT PRIVILEGES FOR ROLE srhbatch IN SCHEMA dwhouse GRANT EXECUTE ON FUNCTIONS TO pichet_ro;  -- pour les fonctions qui seront créées après 

--settings
SELECT name, current_setting(name) FROM pg_settings
WHERE name IN ('max_wal_size', 'checkpoint_timeout', 'wal_compression', 'wal_buffers');

-- current location où on ecrit dans les wal :
SELECT pg_current_xlog_insert_location(); -- 3E/2203E0F8
-- on laisse passer 5 mn et on refait SELECT pg_current_xlog_insert_location(); -- 3D/B4020A58
SELECT pg_xlog_location_diff('3E/2203E0F8', '3D/B4020A58')-- ; donne le resultat en octet de la quantité de données ecrites dans les wal en 5 mn
select 1.0/1024/1024/1024* pg_xlog_location_diff('3E/2203E0F8', '3D/B4020A58'); -- donne le resultat en Mo : 1.718862205
--en 5 mn , la base a généré  ~1.8GB de WAL, donc pour checkpoint_timeout = 30min cela fera environ 10 GB (1.8 * 6) de WAL. toutefois  max_wal_size is a quota for 2 ou 3 checkpoints combinés, so max_wal_size = 30GB (3 x 10GB) semble etre une bonne va
-- leur
-- cache hit ratio : doit être le plus proche de 1, sinon cela veut dire qu'il faut revoir shared_buffers.
SELECT blks_hit::float/(blks_read + blks_hit) as cache_hit_ratio FROM pg_stat_database WHERE datname=current_database();
-- ratio sur le nombre de transaction commité par rapport au nombre de transaction total doit être le + proche de 1, sinon cela veut dire qu'il y a trop de rollback
SELECT xact_commit::float/(xact_commit + xact_rollback) as successful_xact_ratio FROM pg_stat_database WHERE datname=current_database();
-- statistique sur la base 
-- nombre de tuples inserés
select tup_inserted from pg_stat_database WHERE datname=current_database();
-- nombre de tuple supprimés
select tup_deleted from pg_stat_database WHERE datname=current_database();
-- nombre de tuples modifiés
select tup_updated from pg_stat_database WHERE datname=current_database();
-- voir le nombre de backend connectés
select numbackends from pg_stat_database WHERE datname=current_database();
-- voir toutes stats sur la base
select * from pg_stat_database WHERE datname=current_database();
select * from pg_stat_user_tables order by seq_tup_read desc;
-- reiinitialiser les stats :
select pg_stat_reset();
-- ce qui suit necessite l'extension pg_stat_statement
-- donne The total time a query has occupied against your system in minutes
-- The average time it takes to run in milliseconds
-- The query itself
SELECT 
  (total_time / 1000 / 60) as total_minutes, 
  (total_time/calls) as average_time, 
  query 
FROM pg_stat_statements 
ORDER BY 1 DESC 
LIMIT 100;
-- genere des tables
create table test (a int);
insert into test (select generate_series(0,999,1));

------------ statistics
-- reinitiliser les stats , en fait seulement les stats de monitoring (ceux dont les vues commencent par pg_stat_ ou pg_stat_io) et pas les stats de
-- pg_statistics (qui eux sont générés par ANALYSE)
select pg_stat_reset();
-- reinitialise les stats du bgwriter
select pg_stat_reset_shared('bgwriter');
-- donne la liste des stats de la base
select * from pg_stat_database where datname = current_database();
select * from pg_stat_table_();
-- donne la liste des vues du schema pg_catalog

SELECT
n.nspname as "Schema",
c.relname as "Name",
CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN 'special' END as "Type",
r.rolname as "Owner"
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('v','')
AND n.nspname = 'pg_catalog'
AND n.nspname !~ '^pg_toast'
AND pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 1,2;
-- la même mais en + simple , en utilisant une vue
SELECT schemaname,viewname FROM pg_views WHERE schemaname='pg_catalog' ORDER BY viewname;
-- on peut voir toutes vues dans le fichier 
-- vi -R /usr/share/postgresql/9.5/system_views.sql

-- pg_stat_statements
create extension pg_stat_statements;
-- modifier la conf postgres comme ci-dessous :
-- shared_preload_libraries = 'pg_stat_statements' # (change requires restart)
-- pg_stat_statements.max = 10000
-- pg_stat_statements.track = all
-- track_activity_query_size = 2048
-- track_io_timing = on  -- voir /usr/lib/postgresql/9.5/bin/pg_test_timing
SELECT pg_stat_statements_reset(); -- reset les stats
-- createdb pgbench
-- pgbench -i -s 10 pgbench
-- pgbench -c10 -t300 pgbench 
select round(total_time*1000)/1000 as total_time,query from pg_stat_statements order by total_time DESC;
select * from pg_stat_statements;
select * from pg_stat_statements order by blk_read_time desc;
SELECT 1 – sum(shared_blks_read) / sum(shared_blks_hit) FROM pg_stat_statements;

-- fichier de données
create extension pg_buffercache; -- necessaire pour la suite
show data_directory; -- montre le répertoire data
select name,setting from pg_settings where category='File Locations'; -- montre où se trouvent les fichiers de conf
select oid,datname from pg_database where datname='INDUS'; -- 16659
create table t(s SERIAL,i integer);
select relname,relfilenode from pg_class where relname='t'; -- montre le nom du fichier correspondant aux données de la table t. 140380
-- ls -l $HOME/db/pgsql/data/base/16659/140380
-- -rw------- 1 indus01 indus01 0 juil. 20 08:48 /var/webfarm/indus01/db/pgsql/data/base/16659/140380   on voit que le fichier est de taille nulle aprés le create
insert into t(i) values (1);
-- -rw------- 1 indus01 indus01 8192 juil. 20 08:55 /var/webfarm/indus01/db/pgsql/data/base/16659/140380 on voit qu'une page de 8 Ko a été créé sur disque
-- à faire avant checkpont_timeout, montre que isdirty passe à vrai et que usagecount passe à 1. si on fait un deuxieme insert : usage count passe à 2.
select reldatabase,relfilenode,relblocknumber,isdirty,usagecount from pg_buffercache where relfilenode=140380; 


 -- statistiques sur les checkpoints (necessite d'avoir les bonnes infos dans pg_stat_bgwriter.

 -- durée des requetes
	-- ressort les requêtes de srhteams dont la durée dépasse 30 mn et qui ne sont pas idle
select datname,datid,procpid,query_start,age(now(), query_start) as duree,current_query from pg_stat_activity 
where age(now(), query_start) > interval'00:30:00' 
and query_start IS NOT NULL AND current_query NOT LIKE '<IDLE>%' AND usename = 'srhteams'
order by duree desc;
	-- ou la même mais sans interval
select datname,datid,procpid,query_start,age(now(), query_start) as duree,current_query from pg_stat_activity 
where age(now(), query_start) > '30 minutes'   -- '2 hours 27 minutes 35 seconds'
and query_start IS NOT NULL AND current_query NOT LIKE '<IDLE>%' AND usename = 'srhteams'
order by duree desc
	

	-- tiré de check_postgres (query_time): attention : cette requete affiche seulement les requetes avec leur durée d'execution
 BEGIN;SET statement_timeout=30000;COMMIT
 SELECT datname, datid, procpid AS pid, usename, client_addr, current_query AS current_query, '' AS state,
  CASE WHEN client_port < 0 THEN 0 ELSE client_port END AS client_port, 
  COALESCE(ROUND(EXTRACT(epoch FROM now()-query_start)),0) AS seconds 
  FROM pg_stat_activity 
  WHERE (query_start IS NOT NULL AND current_query NOT LIKE '<IDLE>%') AND usename ='srhteams'
  ORDER BY query_start, procpid DESC;

--
 select extract(epoch from now())


 -- autovacuum

 ALTER TABLE rcumulgtaday SET (
  autovacuum_enabled = false, toast.autovacuum_enabled = false
);

-- tablespace

select spcname ,pg_tablespace_location(oid) from   pg_tablespace;
select * from pg_tablespace;

-- les wal   (https://docs.postgresql.fr/10/functions-admin.html#functions-admin-backup-table)
pg_create_restore_point(name text)
select pg_switch_wal()
pg_current_wal_flush_lsn()
pg_current_wal_insert_lsn()
pg_current_wal_lsn()
pg_start_backup(label text [, fast boolean [, exclusive boolean ]])
pg_stop_backup()
pg_stop_backup(exclusive boolean [, wait_for_archive boolean ])
pg_is_in_backup()
pg_backup_start_time()
pg_switch_wal()
pg_walfile_name(lsn pg_lsn)
pg_walfile_name_offset(lsn pg_lsn)
pg_wal_lsn_diff(lsn pg_lsn, lsn pg_lsn)



