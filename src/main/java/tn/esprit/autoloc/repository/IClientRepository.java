package tn.esprit.autoloc.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tn.esprit.autoloc.domain.Client;

/**
 * Repository Spring Data JPA pour l'entité {@link Client}.
 * Proxy généré automatiquement par Spring Data JPA (aucune implémentation à écrire).
 */
public interface IClientRepository extends JpaRepository<Client, Long> {
}
