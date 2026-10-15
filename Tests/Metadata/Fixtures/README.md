# Référence de métadonnées LiveActivityIntent

Les trois champs JSON de live-activity-protocol.json sont extraits des métadonnées réellement compilées par Xcode de EndChargeActivityIntent, conforme à LiveActivityIntent, dans les bundles app et WidgetKit de [MiniWatts v1.5.0](https://github.com/ResistanceTo/MiniWatts/releases/tag/v1.5.0). Ils sont identiques dans les deux bundles. Aucun binaire de référence exécuté ou installé.

Source primaire : MiniWatts/Shared/ChargeActivityAttributes.swift au tag v1.5.0 ; artefact MiniWatts-unsigned.ipa, SHA256 bc13785763ec9ac224710dcf831c8030a318560f409bbcb8d54d23c6379a83e4, égal au digest de l’asset publié. Trois champs du compilateur Apple, aucun nom/paramètre/bundle de cette app copié dans Sport. Le SDK installé exporte LNSystemProtocolIdentifierSessionStarting ; l’API Apple LiveActivityIntent documente l’exécution dans l’app sans l’ouvrir.

Regression : les métadonnées de Sport doivent reproduire ces champs uniquement si les vraies swiftconstvalues déclarent LiveActivityIntent. Le routage iPhone doit être contrôlé séparément.
