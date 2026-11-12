-- ============================================================================
-- AutoLoc — Atelier 2 : Migration des contraintes CHECK des énumérations
-- Base cible : autoloc_db (MySQL 8.0.16+ requis pour les CHECK)
-- Objectif : remplacer les CHECK héritées (IN ('A_DEFINIR')) par les valeurs
--           officielles des 5 enums, SANS toucher aux tables, colonnes ou données.
--
--  ⚠  Script à exécuter MANUELLEMENT, après validation. Ne pas lancer
--     automatiquement. Faire impérativement une sauvegarde au préalable (§0).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. SAUVEGARDE (à exécuter AVANT la migration — commande shell externe)
-- ----------------------------------------------------------------------------
-- Dump complet de la base avant toute modification :
--     mysqldump -u autoloc_user -p autoloc_db > backup_autoloc_pre_atelier2.sql
-- MySQL demandera le mot de passe interactivement.
--   → Ne jamais saisir le mot de passe en clair sur la ligne de commande.
--   → Ne jamais committer de mot de passe dans le dépôt.
-- Le mot de passe provient de la variable d'environnement AUTOLOC_DB_PASSWORD.


USE autoloc_db;


-- ----------------------------------------------------------------------------
-- 1. VÉRIFICATION PRÉ-MIGRATION (lecture seule — ne modifie rien)
-- ----------------------------------------------------------------------------

-- 1a. Lister les CHECK actuelles sur les 4 tables (confirme les noms exacts)
SELECT tc.table_name, tc.constraint_name, cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON tc.constraint_name = cc.constraint_name
 AND tc.constraint_schema = cc.constraint_schema
WHERE tc.table_schema  = 'autoloc_db'
  AND tc.constraint_type = 'CHECK'
  AND tc.table_name IN ('employe','vehicule','reservation','paiement')
ORDER BY tc.table_name, tc.constraint_name;

-- 1b. Valeurs distinctes présentes dans chaque colonne enum
SELECT 'employe.role'            AS colonne, role            AS valeur, COUNT(*) AS nb FROM employe    GROUP BY role
UNION ALL SELECT 'vehicule.categorie',     categorie,                  COUNT(*) FROM vehicule    GROUP BY categorie
UNION ALL SELECT 'vehicule.statut',         statut,                     COUNT(*) FROM vehicule    GROUP BY statut
UNION ALL SELECT 'reservation.statut',      statut,                     COUNT(*) FROM reservation GROUP BY statut
UNION ALL SELECT 'paiement.mode_paiement',  mode_paiement,              COUNT(*) FROM paiement    GROUP BY mode_paiement
ORDER BY colonne, valeur;

-- 1c. Sécurité : aucune ligne ne doit valoir 'A_DEFINIR' (sinon, convertir avant)
SELECT 'employe'        AS t, COUNT(*) AS nb_a_definir FROM employe    WHERE role = 'A_DEFINIR'
UNION ALL SELECT 'vehicule_cat',   COUNT(*) FROM vehicule    WHERE categorie = 'A_DEFINIR'
UNION ALL SELECT 'vehicule_st',    COUNT(*) FROM vehicule    WHERE statut = 'A_DEFINIR'
UNION ALL SELECT 'reservation',    COUNT(*) FROM reservation WHERE statut = 'A_DEFINIR'
UNION ALL SELECT 'paiement',       COUNT(*) FROM paiement    WHERE mode_paiement = 'A_DEFINIR';
-- Attendu : 0 partout.
-- Si > 0, NE PAS continuer : convertir d'abord ces lignes (sans perte de données) :
--   UPDATE employe     SET role          = 'AGENT'       WHERE role = 'A_DEFINIR';
--   UPDATE vehicule    SET categorie     = 'CITADINE'     WHERE categorie = 'A_DEFINIR';
--   UPDATE vehicule    SET statut        = 'DISPONIBLE'   WHERE statut = 'A_DEFINIR';
--   UPDATE reservation SET statut        = 'EN_ATTENTE'  WHERE statut = 'A_DEFINIR';
--   UPDATE paiement    SET mode_paiement = 'CARTE'        WHERE mode_paiement = 'A_DEFINIR';


-- ----------------------------------------------------------------------------
-- 2. MIGRATION DES CONTRAINTES CHECK
--    Pour chaque CHECK : DROP CHECK puis ADD CONSTRAINT avec le MÊME nom et les
--    nouvelles valeurs officielles. Aucune table / colonne / donnée supprimée.
--    Note MySQL 8 : les ALTER sont auto-commités (DDL non transactionnel) ;
--    la vraie sécurité de retour en arrière est la sauvegarde du §0.
-- ----------------------------------------------------------------------------

-- employe.role -> employe_chk_1
ALTER TABLE employe DROP CHECK employe_chk_1;
ALTER TABLE employe ADD CONSTRAINT employe_chk_1 CHECK (role IN ('AGENT','MANAGER'));

-- paiement.mode_paiement -> paiement_chk_1
ALTER TABLE paiement DROP CHECK paiement_chk_1;
ALTER TABLE paiement ADD CONSTRAINT paiement_chk_1 CHECK (mode_paiement IN ('CARTE','ESPECES','VIREMENT'));

-- reservation.statut -> reservation_chk_1
ALTER TABLE reservation DROP CHECK reservation_chk_1;
ALTER TABLE reservation ADD CONSTRAINT reservation_chk_1 CHECK (statut IN ('EN_ATTENTE','CONFIRMEE','ANNULEE','TERMINEE'));

-- vehicule.categorie -> vehicule_chk_1
ALTER TABLE vehicule DROP CHECK vehicule_chk_1;
ALTER TABLE vehicule ADD CONSTRAINT vehicule_chk_1 CHECK (categorie IN ('CITADINE','BERLINE','SUV','UTILITAIRE'));

-- vehicule.statut -> vehicule_chk_2
ALTER TABLE vehicule DROP CHECK vehicule_chk_2;
ALTER TABLE vehicule ADD CONSTRAINT vehicule_chk_2 CHECK (statut IN ('DISPONIBLE','LOUE','MAINTENANCE'));


-- ----------------------------------------------------------------------------
-- 3. VÉRIFICATION POST-MIGRATION (lecture seule)
-- ----------------------------------------------------------------------------

-- 3a. Les CHECK sont bien présentes avec les nouvelles valeurs
SELECT tc.table_name, tc.constraint_name, cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON tc.constraint_name = cc.constraint_name
 AND tc.constraint_schema = cc.constraint_schema
WHERE tc.table_schema  = 'autoloc_db'
  AND tc.constraint_type = 'CHECK'
  AND tc.table_name IN ('employe','vehicule','reservation','paiement')
ORDER BY tc.table_name, tc.constraint_name;
-- Attendu : 5 contraintes, avec les nouvelles listes IN (...).

-- 3b. Test d'acceptation (optionnel, à décommenter puis nettoyer) :
--     une valeur autorisée doit passer, une valeur hors liste doit être rejetée.
-- INSERT INTO employe (nom, prenom, role, id_agence) VALUES ('TEST','T','AGENT', NULL);  -- OK
-- INSERT INTO employe (nom, prenom, role, id_agence) VALUES ('TEST','T','INCONNU', NULL); -- rejetée par employe_chk_1
-- DELETE FROM employe WHERE nom = 'TEST' AND prenom = 'T';

-- 3c. Les données existantes sont inchangées par la migration (DDL de contraintes uniquement).
--     Re-vérifier les valeurs distinctes (identique au §1b) pour le confirmer.

-- ============================================================================
-- Fin du script.
-- ============================================================================
