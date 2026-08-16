# trace_3d

Sketch Processing pour generer un champ de Box3D projete en 2D (wireframe), avec camera orbitale, projection Ortho/Perspective, HLR analytique (ray-casting + BVH), et export SVG direct.

## Objectif

- Produire des traces 2D propres a partir d une scene 3D simple.
- Garder une interaction fluide avec un grand nombre de meshes.
- Permettre des exports vectoriels fiables (affichage et export coherents).

## Demarrage rapide

1. Ouvrir trace_3d.pde dans Processing.
2. Lancer le sketch.
3. Ajuster les parametres via les onglets:
- Meshes
- Camera
- Occlusion
- Style
- Files

Au demarrage, les valeurs sont chargees depuis Settings/default.json.

## Interaction utilisateur

- Drag souris sur le canvas: orbite camera (yaw, pitch).
- Drag clic droit sur le canvas: deplace la cible camera (pan).
- Molette souris sur le canvas:
- Perspective: agit sur target_distance.
- Ortho: agit sur ortho_zoom.
- Boutons Camera: Front, Back, Left, Right, Iso, Top.

Important: les interactions camera sont desactivees si la souris est au-dessus de la GUI.

## Parametres Meshes

L onglet Meshes pilote la distribution des Box3D via un mode actif:
- distribution_mode: Grid ou Tube.
- random_seed: seed global partage par toutes les distributions.

Mode Grid:
- count
- box_size
- box_height

Mode Tube (aleatoire):
- box_count
- levels
- radius_min / radius_max
- base_y_min / base_y_max
- box_length_min / box_length_max
- box_size (section X/Z des boxes)

La geometrie 3D est mise en cache dans meshList et n est reconstruite que si Meshes change.

## Occlusion (HLR)

Quand Occlusion.enabled est actif, le rendu passe par un HLR analytique (ray-casting objet-space, pas de rasterization):
1. Collecte: pour chaque Box3D, un occludeur (bbox monde + centre + diagonale) et ses 12 aretes projetees (coordonnees ecran + coordonnees monde).
2. Un BVH (xlib3d_BVH3D) est construit sur les occludeurs; il n est reconstruit que si la liste de boites change (pas au simple drag camera).
3. Emission: chaque arete est echantillonnee en espace ecran (meme parametrisation qu avant, correcte en perspective via 1/z). A chaque echantillon, le point est deprojete en 3D et un rayon est lance vers la camera contre le BVH pour tester la visibilite exacte (intersection rayon-boite fermee, gere la rotation). Sur un changement de visibilite entre deux echantillons, une bissection affine le point de coupure exact (au lieu de le caler sur la grille d echantillonnage).
4. Auto-occlusion: l origine du rayon est biaisee vers l exterieur de la boite proprietaire de l arete, avec un epsilon proportionnel a la diagonale de cette boite; un seuil specifique evite qu une arete de silhouette s auto-occulte par erreur, tout en laissant une vraie auto-occlusion (face arriere) fonctionner normalement.

Parametres:
- sample_step_px: pas d echantillonnage des aretes en espace ecran.
- bisection_iterations: nombre d iterations de bissection pour affiner un point de coupure de visibilite.
- self_occlusion_eps_scale: facteur (x diagonale de la boite) de l epsilon anti auto-occlusion.
- seam_edges_enabled: ajoute les aretes de "couture" aux zones d intersection entre boites (off par defaut, voir plus bas).

Notes:
- En perspective, la profondeur des aretes est echantillonnee en interpolation 1/z (plus stable sur longues lignes), puis deprojetee en 3D pour le lancer de rayon.
- Avec clipping actif, les echantillons hors du rectangle de clipping sont traites comme non visibles.
- Les occludeurs sont des Box3D (potentiellement tournees, OBB) - le test rayon-boite est exact (methode des slabs en repere local), pas une approximation.

### Aretes de couture (intersections entre boites)

Quand Occlusion.seam_edges_enabled est actif, pour chaque paire de boites qui se
recouvrent (reperees via BVH3D.queryOverlaps, broad-phase AABB), xlib3d_BoxIntersection
calcule les segments ou une face de l une croise une face de l autre (intersection de
plans + double decoupage rectangulaire) et les ajoute comme aretes supplementaires. Une
arete de couture appartient visuellement aux deux boites a la fois (EdgeProjected porte
un second index de proprietaire optionnel), donc les deux beneficient du seuil tolerant
d auto-occlusion. Le calcul est purement geometrique (independant de la camera) et n est
donc refait que lorsque la geometrie des boites change, jamais au simple drag camera -
mais reste potentiellement couteux sur des scenes avec beaucoup de recouvrements, d ou
l option desactivee par defaut.

## Export SVG

Deux options existent dans l onglet Files:
- SVG direct (recommande): writer custom, plus fiable pour le plotter.
- SVG (Processing): fallback legacy via renderer Processing.

Le writer direct:
- applique le clipping dans l espace dessin,
- centre ensuite l export,
- utilise une bbox coherente avec l etat de clipping.

## Architecture du code

Fichiers principaux:
- trace_3d.pde: boucle principale, orchestration recalculs/rendu.
- LineBuilder.pde: generation des lignes 2D (normal + occlusion).
- MeshDistribution.pde: data+UI du mode Meshes et routing Grid/Tube.
- GridDistribution.pde: generation mode Grid.
- TubeDistribution.pde: generation mode Tube aleatoire.
- DataGlobal.pde: aggregation des chapitres de donnees.
- DataGUI.pde: tabs GUI + interactions souris.
- DataOcclusion.pde: parametres HLR + UI Occlusion.
- xlib3d_Mesh.pde: abstraction Mesh + primitives projetees (EdgeProjected, OccluderBox).
- xlib3d_Box3D.pde: decomposition d une box en aretes, intersection rayon-boite (OBB, slab method).
- xlib3d_BVH3D.pde: BVH generique (broad-phase spatial) pour les requetes rayon "any-hit" et de recouvrement AABB.
- xlib3d_BoxIntersection.pde: calcul des aretes de couture entre boites qui se recouvrent.
- xlib3d_Camera3D.pde / xlib3d_CameraData.pde: projection camera + UI + deprojection ecran->monde.

Objets de travail:
- meshList: cache des Mesh.
- lineGroup: geometrie 2D finale affichee/exportee.

Regle de recalcul:
- Meshes change: rebuild meshList puis lignes.
- Camera change: rebuild lignes seulement.
- Occlusion change: rebuild lignes seulement.

## Reglages persistes

Fichier principal:
- Settings/default.json

Chapitres JSON attendus:
- Style
- Page
- Camera
- Boxes
- Occlusion

Si un champ est absent, la valeur par defaut du code est utilisee.

## Notes xLib

Le projet embarque des fichiers xLib_*.pde copies localement. Les evolutions globales xLib se gerent via le workflow de synchronisation du depot processing_xlib.

## TODO

- Hachures (shading) selon l orientation par rapport a la lumiere, attachees au mesh
  comme les aretes de couture (a venir).
- Limitation connue: pendant le calcul HLR (busy), la GUI ControlP5 peut afficher des
  artefacts visuels (lignes 2D visibles au travers, rendu de texte parfois corrompu) la
  ou elle chevauche le contenu 3D/2D. Cause probable: interaction d etat GL entre le
  rendu 3D natif (Preview3D) et l auto-draw de ControlP5, au dela d un simple hint
  depth-test/depth-mask oublie (deja tente, insuffisant). Une fois le calcul termine,
  le rendu est correct. Deprioritise pour l instant (cf. Preview3D.pde).
