# Sport0.10.3 — appui long et zoom ancré

## Autorisation et constat

Pendant la livraison0.10.2, l’utilisateur demande la suppression des piles/photos par appui long puis rapporte sur l’iPhone : zoom depuis le coin supérieur gauche. Demandes ajoutées à la retouche en cours, pas un début du jalon10. Menu contextuel natif, suppression centrée confirmée ; pile = instantané des photos de cette date uniquement, originaux Photos conservés.

Cause statique confirmée : la vue0.10.2 multipliait largeur/hauteur sans compenser l’offset autour du centre du pincement. Aucune reproduction native Linux prétendue. Remplacer cette gestion par UIScrollView native intégrée en UIViewRepresentable dans l’écran SwiftUI : delegate viewForZooming, UIImageView sur canvas commun, pincement/déplacement gérés par iOS. Alternance ne change que l’image ; zoom/offset restent dans la même vue. Les commandes de zoom explicites visent le centre du viewport. Dismantle efface la UIImage et le callback ; masque et session précédents conservés.

## Périmètre et vérification

- Appui long sur pile et photo dans les deux grilles, menu Supprimer rouge et alerte centrée Annuler/Supprimer. UUID session et IDs capturés ; confirmation invalidée au lock.
- Suppression d’une pile en transaction SQLite unique, validation lease avant/après ; aucune base d’entraînement, clé ou autre date touchée. Aucun schéma/permission nouveau.
- Tests pertinents : sous-ensemble supprimé/clé/autres photos conservés, échec SQL après première suppression => rollback intégral, leases invalides/étrangers refusés. Test RED observé deux échecs avant implémentation ; aucune photo réelle utilisée.
- Lint, tests hôte, xtool réel, metadata/inspection, revue indépendante ciblée zoom/lifecycle/suppression, préflight0.10.2, USB/postflight ; arrêt après installation et recette utilisateur.
- Recette : pincer près de chaque coin/détail et déplacer, alterner en gardant cadrage, fermer/revenir, rotation, mask/background ; appui long pile/photo, Annuler conserve, suppression confirmée ne touche pas les autres dates/Photos ; rejeter une confirmation ancienne après lock. VoiceOver et commandes de zoom/alternance.

## Progression

Suppression atomique et contextMenus intégrés. Runtime du nouveau scroll natif à compiler puis tester iPhone. Documentation Apple UIScrollView/zoom/dismantle recherchée ; web renvoie JavaScript et le markdown échoue dans web.run, aucune citation de contenu non lu. APIs standards vérifiées à la compilation contre le SDK réel. Coffre et données utilisateur jamais manipulés par l’agent.


Revue indépendante : un constat Important, aperçu UIImage natif implicite du contextMenu hors mask source. Corrigé par preview explicite neutre (SF Symbol + Photo/Pile privée), sans image ni date. Aucun autre constat étayé zoom/lifecycle/transaction. Vérifier appui long puis inactive/background physiquement ; pas de test UI simulé ni garantie de snapshot non observée.


## Livraison0.10.3(31)

142tests hôte/0échec (5,395s), dont deux nouveaux tests de sous-ensemble et rollback ; deux assertions RED observées avant implémentation. Refus des leases invalides/étrangers de la nouvelle suppression batch également vérifié. Lint strict code0. Wrapper zoom natif et contextMenus compilés xtool18,75s/code0, correctionpreview8,80s/code0 ; générationmetadata réelle puis empaquetage2,15s/code0, six testsmetadata et inspectionunsigned réussis.

Revue indépendante : constat Important de preview natif privé corrigé dans les deux grilles par aperçu neutre sans image/date ; source et compilation finale contrôlées. Aucun autre problème étayé relevé par la revue. Préflightlecture seule0.10.2 code0 : même identité et certificat existant valide>24h/présentApple. device-run.sh code0, rebuild2,19s, installation/vérification100%. Postflight direct0.10.3 code0 : mêmes app/widget, profilsvalides CMSvérifiés, certificatpréflight/local inchangés. Aucune permission nouvelle/AppGroup/push, cache/SDK/HelloSportlocal conservés.

La build est installée avant review. Le bug d’ancrage est un constat utilisateur sur0.10.2 ; aucun succès natif d’ancrage/pan/tap ou d’appui long n’est prétendu sous Linux. Recette du README et confirmation iPhone attendues ; ne pas commencer le10. Aucun média réel ni suppression sur les données de l’utilisateur exécuté par l’agent.
