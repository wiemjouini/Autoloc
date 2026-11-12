# AutoLoc — Stratégie de Fetch, Cascade & Associations (Atelier 2)

Document de référence de la couche JPA du projet AutoLoc. Récapitule les associations, le fetch et les
cascades retenus, puis explique les concepts clés. Configuration finale : **fetch LAZY partout**.

## 1. Tableau récapitulatif des associations

| # | Association | Cardinalité | Fetch retenu | Cascade retenue | Côté propriétaire (FK) | Justification métier |
|---|-------------|-------------|--------------|-----------------|------------------------|----------------------|
| 1 | Agence → Employe | 1:N | LAZY | aucune | `Employe.id_agence` | Une agence regroupe plusieurs employés ; liste chargée à la demande. Supprimer une agence ne doit pas effacer ses employés (données RH). |
| 2 | Agence → Vehicule | 1:N | LAZY | aucune | `Vehicule.id_agence` | Une agence gère un parc de véhicules ; chargement paresseux. Supprimer une agence ne détruit pas le parc véhicule. |
| 3 | Client → Reservation | 1:N | LAZY | `PERSIST` | `Reservation.id_client` | Un client a plusieurs réservations. `PERSIST` enregistre une réservation quand on persiste le client. Pas de `REMOVE` : l'historique commercial est conservé. |
| 4 | Reservation ↔ Vehicule | 1:N / N:1 | LAZY (2 côtés) | aucune (2 côtés) | `Reservation.id_vehicule` | Une réservation référence un véhicule existant. Aucune cascade des deux côtés (TP2 strict) : on ne crée ni ne supprime un véhicule via une réservation, ni de réservation via le véhicule. Les réservations sont persistées via `Reservation` directement ou via `Client.reservations` (`PERSIST` conservé). |
| 5 | Reservation ↔ Contrat | 1:1 | LAZY (2 côtés) | `ALL` côté Reservation | `Contrat.id_reservation` | Le contrat dépend de la réservation. `ALL` côté Reservation propage persist/merge/remove vers le contrat lié. Propriétaire = Contrat (porte la FK). |
| 6 | Contrat → Paiement | 1:N | LAZY | `ALL` + `orphanRemoval=true` | `Paiement.id_contrat` | Les paiements appartiennent au contrat et en suivent le cycle de vie. `orphanRemoval` supprime un paiement retiré de la liste. |
| 7 | Vehicule ↔ Equipement | N:N | LAZY (2 côtés) | aucune | `Vehicule` via `vehicule_equipement` | Un véhicule possède plusieurs équipements, eux-mêmes partagés. Pas de cascade (équipements indépendants et mutualisés). `Set` pour éviter les doublons. |
| 8 | Vehicule → Maintenance | 1:N | LAZY | `PERSIST` côté Vehicule | `Maintenance.id_vehicule` | Historique d'entretien d'un véhicule. `PERSIST` crée des maintenances via le véhicule. Pas de `REMOVE` : l'historique est conservé. |

Notes :
- Côté propriétaire = côté qui porte la clé étrangère (`@JoinColumn`) ou la table de jointure (`@JoinTable`).
- Toutes les `@ManyToOne` / `@OneToOne` sont en `LAZY` explicite ; les `@OneToMany` / `@ManyToMany` sont `LAZY` (par défaut Hibernate, ici rendu explicite).
- Aucune cascade `REMOVE` n'est posée sur `Agence` ni sur `Vehicule`.

## 2. Contrat ↔ Paiement — démarche pédagogique en 5 étapes

L'association existe déjà et est correcte. Ce qui suit explique les étapes **sans supprimer ni recréer les
tables**. Configuration finale retenue : **LAZY**.

1. **Unidirectionnelle** — On part d'un seul côté : `Paiement` porte
   `@ManyToOne(fetch = LAZY) @JoinColumn(name = "id_contrat") Contrat contrat`. À ce stade, un `Contrat`
   ne « voit » pas encore ses paiements.
2. **Bidirectionnelle** — On ajoute côté `Contrat` la collection inverse
   `@OneToMany(mappedBy = "contrat") List<Paiement> paiements`. `mappedBy = "contrat"` pointe vers le champ
   propriétaire `Paiement.contrat`. La FK reste sur `Paiement` ; aucune colonne n'est ajoutée côté `Contrat`.
3. **Cascade** — `cascade = CascadeType.ALL` côté `Contrat` : persist/merge/remove/refresh/detach d'un contrat
   se propagent à ses paiements. Pratique pour gérer le cycle de vie des paiements avec celui du contrat.
4. **orphanRemoval** — `orphanRemoval = true` : un paiement retiré de `paiements` (donc « orphelin » de son
   contrat) est supprimé de la base. Comportement dédié à la composition : un paiement n'existe pas sans contrat.
5. **Comparaison LAZY / EAGER** —
   - `EAGER` chargerait toute la liste de paiements à chaque lecture d'un contrat (même si on n'en a pas
     besoin) → risque de surcharge et de problèmes N+1.
   - `LAZY` ne charge les paiements que lorsqu'on accède réellement à `paiements`.
   - Choix retenu : **LAZY**, conforme au TP.

## 3. Concepts JPA

### LAZY vs EAGER
- **EAGER** : l'association est chargée immédiatement avec l'entité propriétaire. À réserver aux associations
  quasi-systématiquement consultées et de petite taille. Provoque des jointures et peut dégrader les performances.
- **LAZY** : l'association est chargée à la première utilisation (proxy / collection non initialisée). Limite
  le volume de données et le nombre de requêtes.
- Règle AutoLoc : **LAZY partout** (y compris sur les collections `@OneToMany` / `@ManyToMany`, déjà `LAZY` par
  défaut chez Hibernate, ici rendu explicite). Charger explicitement via une requête JPQL `JOIN FETCH`
  quand nécessaire.

### CascadeType.ALL
Équivaut à `PERSIST + MERGE + REMOVE + REFRESH + DETACH`. Pratique quand l'entité enfant n'a pas de sens sans
le parent (composition). À éviter sur des associations où l'enfant est partagé ou possède son propre cycle de
vie (sinon suppression en cascade involontaire).

### orphanRemoval
Supprime automatiquement de la base une entité enfant lorsqu'elle n'est plus référencée par le parent (retirée
de la collection). Concerne la **composition** : l'enfant vit et meurt avec le parent. Différent d'une cascade
`REMOVE` simple : `orphanRemoval` réagit au retrait de la collection, pas seulement à la suppression du parent.
Dans AutoLoc : `Contrat → Paiement`.

### mappedBy
Indique le côté **inverse** d'une association bidirectionnelle. La valeur désigne le nom du champ côté
propriétaire. Le côté propriétaire porte la FK (`@JoinColumn`) ou la table de jointure (`@JoinTable`) ; le côté
inverse ne crée aucune colonne. Règle : un seul côté propriétaire par association.

### Pourquoi les suppressions ne doivent pas se propager à toutes les associations
- **Intégrité métier** : supprimer une agence ne doit pas effacer ses employés (RH) ni son parc véhicule ;
  supprimer un client ne doit pas effacer son historique de réservations.
- **Données partagées** : un `Equipement` est partagé par plusieurs véhicules — propager un `REMOVE` détruirait
  des équipements encore utilisés ailleurs.
- **Historique / traçabilité** : les maintenances, réservations et paiements sont des faits historiques à
  conserver.
- **Sécurité** : des cascades `REMOVE` mal placées peuvent causer des suppressions massives involontaires.
  AutoLoc limite la propagation de suppression à la composition `Contrat → Paiement` (via `ALL` /
  `orphanRemoval`) et à `Reservation → Contrat` (via `ALL`). Aucune cascade `REMOVE` sur `Agence` ni `Vehicule`.
