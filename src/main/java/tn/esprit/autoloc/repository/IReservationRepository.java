package tn.esprit.autoloc.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tn.esprit.autoloc.domain.Reservation;

/**
 * Repository Spring Data JPA pour l'entité {@link Reservation}.
 * Proxy généré automatiquement par Spring Data JPA (aucune implémentation à écrire).
 */
public interface IReservationRepository extends JpaRepository<Reservation, Long> {
}
