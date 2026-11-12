package tn.esprit.autoloc.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import tn.esprit.autoloc.domain.Contrat;
import tn.esprit.autoloc.repository.IContratRepository;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Démonstration CRUD isolée sur {@link Contrat}, DÉSACTIVÉE par défaut.
 *
 * <p>Ne s'exécute que si la propriété {@code autoloc.demo.contrat.enabled=true} est définie.
 * Par défaut (propriété absente), ce composant n'est pas créé et n'écrit rien en base.
 *
 * <p>Lorsqu'elle est active, la démo :
 * <ol>
 *   <li>{@code save()} : crée un NOUVEAU Contrat (ne lit ni ne modifie aucune donnée existante),</li>
 *   <li>{@code findById()} : relit ce contrat via un {@link java.util.Optional},</li>
 *   <li>{@code deleteById()} : supprime UNIQUEMENT la ligne qu'elle vient de créer.</li>
 * </ol>
 * Les logs SQL (INSERT/SELECT/DELETE) sont visibles grâce à
 * {@code spring.jpa.show-sql=true} et {@code logging.level.org.hibernate.SQL=DEBUG}.
 *
 * <p><b>Écritures produites lors de l'exécution :</b> un INSERT puis un DELETE sur la table
 * {@code contrat} (la ligne créée par la démo). Aucune donnée existante n'est lue, modifiée
 * ou supprimée. L'auto-incrément de {@code id_contrat} avance d'un cran (trou dans la séquence).
 */
@Component
@ConditionalOnProperty(name = "autoloc.demo.contrat.enabled", havingValue = "true")
public class ContratCrudDemoRunner implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(ContratCrudDemoRunner.class);

    private final IContratRepository contratRepository;

    public ContratCrudDemoRunner(IContratRepository contratRepository) {
        this.contratRepository = contratRepository;
    }

    @Override
    public void run(String... args) {
        // 1. save() : crée un nouveau Contrat (réservation nulle => aucune donnée existante liée)
        Contrat contrat = new Contrat();
        contrat.setDateSignature(LocalDate.now());
        contrat.setMontantTotal(new BigDecimal("99.90"));
        contrat.setValide(false);
        Contrat saved = contratRepository.save(contrat);
        log.info("save() -> Contrat créé, idContrat={}", saved.getIdContrat());

        // 2. findById() : relecture via Optional
        contratRepository.findById(saved.getIdContrat())
                .ifPresentOrElse(
                        c -> log.info("findById({}) -> trouvé : montant={}, valide={}",
                                c.getIdContrat(), c.getMontantTotal(), c.isValide()),
                        () -> log.warn("findById({}) -> absent", saved.getIdContrat()));

        // 3. deleteById() : supprime uniquement la ligne créée par cette démo
        Long id = saved.getIdContrat();
        contratRepository.deleteById(id);
        log.info("deleteById({}) -> supprimé. existsById={}", id, contratRepository.existsById(id));
    }
}
