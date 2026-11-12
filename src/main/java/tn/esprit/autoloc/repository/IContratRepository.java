package tn.esprit.autoloc.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tn.esprit.autoloc.domain.Contrat;

/**
 * Repository Spring Data JPA pour l'entité {@link Contrat}.
 * Le proxy d'implémentation est généré automatiquement par Spring Data JPA
 * (aucune classe d'implémentation à écrire).
 */
public interface IContratRepository extends JpaRepository<Contrat, Long> {
}
