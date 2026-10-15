# Prototype physique — icône Kavi dans Sport

Demande explicite : installer l’icône de Kavi dans Sport pour comparer son rendu au vrai Kavi sur l’iPhone. Test temporaire : aucune création du logo Sport, aucune modification de Kavi ni changement d’identité Sport. La todo d’icône personnalisée reste ouverte.

Sources de référence : dossier AppIcon.icon de github.com/raaaton/Kavi, branche main, copié sous Resources/KaviReference.icon (icon.json et trois SVG, dont deux utilisés). Les PNG de secours argentés ne représentent pas les couches menthe actuelles ; on compile bien ces couches.

L’actool Linux installé dans omarchy-apple-dev sait compiler ces couches en Assets.car, images de secours et déclaration plist. Prototype précédent sur copie temporaire réussi, mais ne prouve pas le rendu iPhone. scripts/build-app-icon.py compile les sources sans signature et contrôle les déclarations. xtool.yml copie les ressources compilées à la racine de l’app ; Sport-Info.plist déclare l’icône. Le build/version app et widget passent à 0.11.10 (44) ; aucune capacité ou permission ajoutée.

Vérification : compilation icône, lint strict, tests metadata, xtool dev build, contrôle réel du bundle avec égalité des ressources icône, préflight app/certificat, installation USB autorisée, postflight appareil. Les tests de domaine ne sont pas relancés pour un changement de ressources seul. La comparaison de verre, relief, couleurs et variantes Home Screen doit être faite par l’utilisateur. Aucun résultat visuel prétendu sur la seule base du catalogue compilé.

Progression : configuration en place, lint et 6 metadata réussis. Compilation icon et build/install en cours.

Livraison : actool code 0, Assets.car et PNG générés, déclaration compilée égale au plist Sport. Le sandbox bloquait CFSocket ; seule la tentative bloquée a été arrêtée et la compilation reprise hors sandbox. Lint strict/6metadata réussis, xtool 2,21 s, inspection réelle app/widget et égalité des fichiers icône réussies. Script USB code 0 (rebuild 2,09 s), installation/vérification 100 %. Postflight direct : Sport 0.11.10 (44), même identité/certificat et profils CMS valides. Aucun nouvel entitlement/permission ni lecture de données/photos personnelles. Attendre comparaison physique des rendus avant de décider de l’icône Sport définitive.
