# Planche 2 de Riffald — prompts pour générateur d'images

Référence : [riffald_turnaround.jpg](riffald_turnaround.jpg) (à joindre comme image de référence si le
générateur le permet : Midjourney `--cref` / `--sref`, Gemini, ChatGPT, Stable Diffusion + IP-Adapter).

## Prompt (anglais — recommandé)

```
Character turnaround sheet of Riffald, a heavy-metal bard hero for a dark fantasy hack-and-slash video game.
Three full-body views side by side at the same scale: front view, back view, left profile view. Neutral standing
A-pose, arms slightly away from the body, feet shoulder-width apart, whole character visible from head to boots.
Stylized 3D render, game-ready hero, heroic proportions (about 7.5 heads tall, broad shoulders, V-shaped torso,
narrow waist, long legs, slightly oversized hands and boots), exaggerated shapes, clear readable silhouette.
Face: sharp angular jaw, high cheekbones, intense frowning eyes, confident smirk, clean-shaven, silver earring,
expressive and charismatic.
Hair: huge voluminous wild curly mane, bright flame orange, falling below the shoulders in thick chunky locks.
Outfit: worn black studded leather jacket with high collar, open on a dark shirt; oversized dark steel pauldrons
each with three big silver spikes, attached with leather straps and square iron buckles; crossed leather straps on
the chest; studded choker with hanging silver chains and a glowing ruby red gemstone pendant; studded belt with a
large buckle; black leather trousers with dark steel knee guards; black fingerless leather gloves; tall black boots
with straps, buckles, studs and spiked toes and heels; long burgundy cape, torn into jagged tatters at the bottom,
attached under the pauldrons, flowing slightly.
Materials: stylized hand-painted PBR, worn leather with visible scratches, brushed dark metal with bright rim
highlights, rich burgundy cloth, glossy red gem. Saturated video game colors, strong color contrast
(black / burgundy / flame orange / silver / ruby red), soft studio lighting with orange and cool blue rim lights,
subtle outline, cel-shaded accents.
Plain flat light grey background, no scenery, no props, no text, no weapon.
Style references: Blizzard / World of Warcraft, Overwatch, League of Legends splash-art quality, Diablo IV character art.
```

## Prompt (français)

```
Planche de personnage (turnaround) de Riffald, barde héroïque de heavy metal pour un jeu vidéo hack'n'slash de
dark fantasy. Trois vues en pied côte à côte, à la même échelle : face, dos, profil gauche. Pose neutre en A, bras
légèrement écartés du corps, pieds à largeur d'épaules, personnage entier visible de la tête aux bottes.
Rendu 3D stylisé de héros de jeu vidéo, proportions héroïques (environ 7,5 têtes, larges épaules, torse en V,
taille fine, longues jambes, mains et bottes légèrement surdimensionnées), formes exagérées, silhouette lisible.
Visage : mâchoire anguleuse, pommettes hautes, regard intense aux sourcils froncés, sourire en coin assuré, rasé
de près, boucle d'oreille en argent, visage expressif et charismatique.
Cheveux : énorme crinière bouclée et sauvage, orange flamboyant, qui tombe sous les épaules en grosses mèches.
Tenue : veste de cuir noir usé et clouté à col montant, ouverte sur une chemise sombre ; énormes épaulières d'acier
sombre, chacune avec trois grandes pointes argentées, fixées par des sangles de cuir et des boucles carrées en fer ;
sangles de cuir croisées sur la poitrine ; collier clouté avec chaînes d'argent et pendentif en rubis rouge lumineux ;
ceinture cloutée à grosse boucle ; pantalon de cuir noir avec genouillères d'acier sombre ; mitaines de cuir noir ;
hautes bottes noires à sangles, boucles, clous, pointes au bout et au talon ; longue cape bordeaux déchirée en
lambeaux en bas, attachée sous les épaulières, légèrement flottante.
Matériaux stylisés peints à la main : cuir usé et rayé, métal sombre brossé avec reflets vifs, tissu bordeaux riche,
gemme rouge brillante. Couleurs saturées de jeu vidéo, fort contraste (noir / bordeaux / orange flamboyant / argent /
rouge rubis), éclairage de studio doux avec contre-jours orange et bleu froid, léger contour, touches de cel shading.
Fond gris clair uni, sans décor, sans accessoires, sans texte, sans arme.
Références de style : Blizzard / World of Warcraft, Overwatch, qualité des illustrations de League of Legends,
personnages de Diablo IV.
```

## Prompt négatif (Stable Diffusion, Leonardo…)

```
background scenery, landscape, props, weapon, guitar, text, watermark, logo, signature, cropped, cut off feet,
cut off head, extra limbs, extra fingers, deformed hands, asymmetric views, different characters, inconsistent
outfit between views, beard, helmet, photorealistic, blurry, low detail, flat shading, dark muddy colors
```

## Réglages conseillés

- **Midjourney** : ajouter `--ar 16:9 --style raw --stylize 250` (et `--cref <lien de la planche 1> --cw 60`
  pour garder le même personnage).
- **Stable Diffusion XL / Flux** : format 1792×1024, CFG 6–7, 30–40 pas ; ControlNet OpenPose avec trois
  silhouettes en A-pose pour des vues cohérentes.
- **ChatGPT / Gemini** : joindre la planche 1 et préciser « même personnage, rendu 3D stylisé, trois vues ».
- Si les trois vues ne sont pas cohérentes, générer chaque vue séparément avec la même graine (seed) et la même
  référence, puis les assembler.
