# AutoLoc — Atelier 3 : Notes sur la couche Repository (Spring Data JPA)

## 1. Repositories créés

Les 9 interfaces ci-dessous sont placées dans `tn.esprit.autoloc.repository` et étendent
`JpaRepository<Entité, Long>`. Aucune classe d'implémentation : Spring Data JPA génère le proxy
au démarrage.

| Repository | Entité | ID | Rôle métier |
|---|---|---|---|
| `IAgenceRepository` | `Agence` | `Long` | Agences de location |
| `IEmployeRepository` | `Employe` | `Long` | Employés rattachés à une agence |
| `IVehiculeRepository` | `Vehicule` | `Long` | Parc véhicule des agences |
| `IEquipementRepository` | `Equipement` | `Long` | Équipements (N:N avec Vehicule) |
| `IClientRepository` | `Client` | `Long` | Clients locataires |
| `IReservationRepository` | `Reservation` | `Long` | Réservations client/véhicule |
| `IContratRepository` | `Contrat` | `Long` | Contrats liés à une réservation |
| `IPaiementRepository` | `Paiement` | `Long` | Paiements d'un contrat |
| `IMaintenanceRepository` | `Maintenance` | `Long` | Maintenances d'un véhicule |

### Justification de `JpaRepository`

`JpaRepository` est l'interface la plus riche du socle Spring Data JPA. Elle combine :
- le CRUD (via `ListCrudRepository`) avec des retours en `List` plutôt que `Iterable`,
- le tri et la pagination (via `ListPagingAndSortingRepository`),
- des opérations JPA spécifiques : `flush()`, `saveAndFlush()`, `saveAllAndFlush()`,
  `deleteAllInBatch(...)`, `deleteAllByIdInBatch(...)`, `deleteInBatch(...)`, `getReferenceById(...)`,
- l'exécution par exemple (`QueryByExampleExecutor`).

Pour AutoLoc, on aura besoin de paginer/trier des listes (véhicules, réservations), de flusher
explicitement dans certaines transactions, et de faire des suppressions par lot. `JpaRepository`
couvre tous ces cas sans code supplémentaire. C'est le choix standard pour une application JPA.

## 2. Comparaison des interfaces Spring Data

Hiérarchie (Spring Data 2025.x / Spring Boot 4) :

```
Repository<T, ID>                            (marqueur vide)
 ├─ CrudRepository<T, ID>                    (CRUD, retours Iterable)
 │   └─ ListCrudRepository<T, ID>            (CRUD, retours List)
 ├─ PagingAndSortingRepository<T, ID>        (tri + pagination, Iterable)
 │   └─ ListPagingAndSortingRepository<T, ID> (tri + pagination, List)
 └─ JpaRepository<T, ID>                      (extends ListCrudRepository
                                               + ListPagingAndSortingRepository
                                               + QueryByExampleExecutor)
```

| Interface | Hérite de | Méthodes clés | Retours collection | Spécificités |
|---|---|---|---|---|
| `Repository` | — | aucune (marqueur) | — | Base de la hiérarchie ; sert à typer sans exposer de méthodes. |
| `CrudRepository` | `Repository` | `save`, `findById`, `findAll`, `count`, `deleteById`, `existsById`… | `Iterable` | CRUD de base. Retours `Iterable` peu pratiques à consommer. |
| `ListCrudRepository` | `CrudRepository` | mêmes CRUD | `List` | Variante moderne (Spring Data 3+) : `findAll()` / `saveAll()` renvoient `List`. |
| `PagingAndSortingRepository` | `Repository` | `findAll(Sort)`, `findAll(Pageable)` | `Iterable` / `Page` | Tri et pagination seuls (pas de CRUD). |
| `JpaRepository` | `ListCrudRepository` + `ListPagingAndSortingRepository` + `QueryByExampleExecutor` | CRUD (List) + tri/pagination + batch + flush | `List` / `Page` | Le plus complet ; spécifique à JPA. |

Choix AutoLoc : `JpaRepository` pour les 9 entités (CRUD + pagination/tri + batch + flush).

## 3. Méthodes essentielles

### `save(entity)`
- Si l'entité n'a pas d'identifiant (nouvelle) → `INSERT`.
- Si l'identifiant existe (détachée / modifiée) → `SELECT` de vérification puis `UPDATE`
  (stratégie de merge).
- Retourne l'instance gérée (id généré, version, etc.). Important : utiliser la valeur
  retournée, pas l'instance passée en argument.

### `findById(id)` — `Optional<T>`
- Retourne `Optional<T>` : vide si l'entité n'existe pas. À privilégier sur `getOne()` /
  `getReferenceById()` (qui renvoient un proxy paresseux et lèveront une exception plus tard).
- Usage typique : `repo.findById(id).ifPresentOrElse(c -> ..., () -> ...);`

### `deleteById(id)`
- Effectue un `SELECT` (chargement) puis un `DELETE`. Deux requêtes.
- Si l'id n'existe pas : **no-op** dans les versions récentes de Spring Data JPA (aucune exception).
- Les cascades JPA et `orphanRemoval` **s'appliquent** (entité chargée puis supprimée).

### Suppressions en lot (batch)
- `deleteAllInBatch(Iterable<T>)`, `deleteAllByIdInBatch(Iterable<ID>)`, `deleteInBatch(T)` :
  un seul `DELETE ... WHERE id IN (...)`. Pas de `SELECT` préalable. **Rapide, mais les cascades
  JPA et `orphanRemoval` NE s'appliquent PAS** (le cycle de vie Hibernate est contourné).
- `deleteAll()`, `deleteAllById(...)`, `delete(Iterable)` : chargent les entités puis les
  suppriment une à une ; cascades et callbacks appliqués, mais plus lent (problème N+1).

> ⚠ Pour AutoLoc : `Contrat → Paiement` est en `cascade = ALL` + `orphanRemoval`. Utiliser
> `deleteInBatch` / `deleteAllInBatch` sur un `Contrat` **ne supprimera pas** ses paiements.
> Pour respecter la composition, utiliser `delete()` / `deleteById()` (chargement + cascade).

## 4. Démonstration CRUD (désactivée par défaut)

`tn.esprit.autoloc.demo.ContratCrudDemoRunner` est un `CommandLineRunner` annoté
`@ConditionalOnProperty(name = "autoloc.demo.contrat.enabled", havingValue = "true")`.

- **Désactivé par défaut** : tant que la propriété est absente (ou différente de `true`), le
  bean n'est pas créé → aucun accès base, aucune écriture.
- **Activation** : ajouter dans `application.properties`
  `autoloc.demo.contrat.enabled=true`, ou lancer avec
  `--autoloc.demo.contrat.enabled=true` en argument de démarrage.
- **Écritures avant exécution** : à l'activation, la démo fait un `INSERT` puis un `DELETE`
  sur `contrat` (la ligne qu'elle crée). Aucune donnée existante n'est lue / modifiée / supprimée.
  L'auto-incrément `id_contrat` avance d'un cran (trou dans la séquence).
- **Logs SQL** : visibles via `spring.jpa.show-sql=true` +
  `logging.level.org.hibernate.SQL=DEBUG` (déjà configurés).

## 5. Anomalies SonarQube for IDE (à compléter)

Le tableau ci-dessous doit être rempli après analyse **SonarQube for IDE** (ex-SonarLint).

Outil : plugin IDE (VS Code / IntelliJ). S'il n'est pas installé, à ajouter depuis le
Marketplace de l'IDE (nom : « SonarQube for IDE » / « SonarLint »). Utilité : détecter en
temps réel les problèmes de qualité et de sécurité dans l'éditeur. Je n'installe rien
automatiquement (accord requis au préalable).

| Règle SonarQube | Fichier / emplacement | Explication | Correction proposée | Statut |
|---|---|---|---|---|
| _(à compléter)_ | | | | |

Étapes : installer / activer SonarQube for IDE → ouvrir le projet → examiner les diagnostics
remontés sur `tn.esprit.autoloc.repository` (et la démo `tn.esprit.autoloc.demo`) → reporter
chaque règle (ex. `java:S...`) avec son explication et la correction appliquée.
