# Sport 0.11.8 — symboles des boutons Liquid Glass

Demande du 15 octobre : symboles blancs dans les boutons des barres d’outils système, sauf les coches qui conservent l’accent. Application locale de foregroundStyle aux boutons et aux libellés déclenchant les menus ; aucune recoloration du menu lui-même. Les actions destructives restent rouges et les commandes/états désactivés conservent leur comportement. Aucun composant verre personnalisé, changement métier, permission ou logique du coffre.

Todo : échauffement configurable par séance ajouté ; icône personnalisée déjà présente, sans doublon. Ces deux fonctionnalités ne sont pas implémentées dans ce correctif.

Vérifications : lint Swift strict réussi ; 6 tests de métadonnées réussis ; xtool dev build réussi (13,95 s), génération des métadonnées et second build réussi (2,09 s) ; inspection réelle app/extension 0.11.8 (42) réussie. Pas de tests de domaine supplémentaires : aucune logique modifiée. Préflight : une seule app Sport 0.11.7 (41), même identifiant effectif, certificat local valide et présent dans la liste Apple. Installation et contrôle appareil à consigner.

Recette iPhone : vérifier les symboles +, fermer, modifier, options, zoom et comparaison dans les barres d’outils ; coches d’enregistrement toujours accentuées, actions destructives rouges et boutons désactivés reconnaissables. Vérifier la lisibilité en apparences claire/sombre. Le build ne valide pas le rendu physique.

Livraison : device-run.sh code 0, build incrémental 1,93 s, installation/vérification 100 %. Postflight direct : Sport 0.11.8 (42), identité effective et certificat inchangés ; profils app/widget avec signature CMS et validité contrôlées, aucune nouvelle capacité App Group/push. iOS conserve plusieurs profils historiques pour les mêmes deux identités : contrôle adapté aux identités distinctes, sans suppression de profil. Lint strict et vérification unsigned relancés avec succès. Aucun accès aux photos/données personnelles. Recette visuelle iPhone en attente.

Retour du 15 octobre : utilisateur constate aucun changement sur History + et croix de la modale. 0.11.8 a été relue sur l’appareil ; défaut de style confirmé par ce retour, et non problème d’installation. Cette version ne valide donc pas le rendu blanc. Correction suivante : [teinte native 0.11.9](2026-10-15-native-toolbar-tint.md).
