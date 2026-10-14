{
		// banner comments generated in http://patorjk.com/software/taag/#p=display&c=c&f=ANSI%20Regular&t=base
		/***
		 *    ██████   █████  ███████ ███████
		 *    ██   ██ ██   ██ ██      ██
		 *    ██████  ███████ ███████ █████
		 *    ██   ██ ██   ██      ██ ██
		 *    ██████  ██   ██ ███████ ███████
		 *
		 *
		 */
		"base": {
			show: true,
			filters: ["tan"],
			z: ZIndices.base,
			animation: "idle",

			srcfn(options) {
				return options.mannequin ? "img/body/mannequin/base-body.png" : `img/body/base-${options.body_type}.png`;
			},
		},
		"basehead": {
			show: true,
			filters: ["tan"],
			z: ZIndices.basehead,
			animation: "idle",

			srcfn(options) {
				return options.mannequin ? "img/body/mannequin/base-head.png" : "img/body/base-head.png";
			},
		},
		"breasts": {
			show: true,
			filters: ["tan"],
			z: ZIndices.breasts,
			animation: "idle",

			masksrcfn(options) {
				return options.breasts_mask_src;
			},
			srcfn(options) {
				const mannequin = (options.mannequin) ? "mannequin/" : "";
				const prefix = `img/body/${mannequin}`;
				const breasts = options.breasts === "cleavage" && options.breast_size >= 3 ? "clothed" : "breasts";
				return `${prefix}breasts/${breasts}-${options.breast_size}.png`;
			},
		},
		"belly": {
			filters: ["tan"],
			z: ZIndices.bellyBase,
			animation: "idle",

			showfn(options) {
				return !!options.belly
			},
			srcfn(options) {
				return between(options.belly, 1, 24) ? `img/body/pregnant-belly/${options.belly}.png` : "";
			},
		},
		"bellyLeft": {
			filters: ["tan"],
			z: ZIndices.bellyBase,
			animation: "idle",

			showfn(options) {
				return !!options.belly
			},
			srcfn(options) {
				return options.body_type === "soft" && between(options.belly, 11, 14) ? `img/body/pregnant-belly/${options.belly}.png` : "";
			},
			masksrcfn(options) {
				return options.upper_fitted_left_move_src;
			},
			dxfn(options) {
				return 2;
			},
		},
		"bellyRight": {
			filters: ["tan"],
			z: ZIndices.bellyBase,
			animation: "idle",

			showfn(options) {
				return !!options.belly
			},
			srcfn(options) {
				return options.body_type === "soft" && between(options.belly, 11, 14) ? `img/body/pregnant-belly/${options.belly}.png` : "";
			},
			masksrcfn(options) {
				return options.upper_fitted_right_move_src;
			},
			dxfn(options) {
				return -2;
			},
		},
		"nipples_parasite": {
			z: ZIndices.breastsparasite + 0.1,
			animation: "idle",

			showfn(options) {
				return !!options.nipples_parasite;
			},
			srcfn(options) {
				switch (options.nipples_parasite) {
					case "urchin":
						return `img/body/breasts/urchin-${options.breast_size}.png`;
					case "slime":
						return `img/body/breasts/slime-${options.breast_size}.png`;
					default:
						return "";
				}
			},
		},
		"breasts_parasite": {
			filters: ["breasts_parasite"],
			z: ZIndices.breastsparasite,
			animation: "idle",

			showfn(options) {
				return !!options.breasts_parasite;
			},
			srcfn(options) {
				return options.breasts_parasite === 'parasite' ? `img/body/breasts/ear-slime-${options.breast_size}.png` : "";
			},
		},
		"leftarm": {
			filters: ["tan"],
			animation: "idle",

			zfn(options) {
				return (options.arm_left === "cover") ? ZIndices.left_cover_arm : ZIndices.armsidle;
			},
			showfn(options) {
				return options.arm_left !== "none";
			},
			srcfn(options) {
				if (options.mannequin) return "img/body/mannequin/left-arm-idle.png";
				if (options.arm_left === "cover") return "img/body/left-arm-cover.png";
				return `img/body/left-arm-idle-${options.body_type}.png`;
			},
		},
		"rightarm": {
			filters: ["tan"],
			animation: "idle",

			zfn(options) {
				if (["cover", "hold"].includes(options.arm_right)) return ZIndices.right_cover_arm;
				return ZIndices.armsidle;
			},
			showfn(options) {
				return options.arm_right !== "none";
			},
			srcfn(options) {
				if (options.mannequin) return `img/body/mannequin/right-arm-${options.arm_right}.png`;
				if (options.arm_right === "idle") return `img/body/right-arm-idle-${options.body_type}.png`;
				return `img/body/right-arm-${options.arm_right}.png`;
			},
		},
		"tummy_parasite": {
			filters: ["tummy_parasite"],
			animation: "idle",

			srcfn(options) {
				switch (options.tummy_parasite) {
					case "urchin":
						/* Swap to img/body/tummyurchingray for new sprites, make sure to include colour changes to the code */
						return 'img/body/parasites/urchin-tummy.png';
					case "slime":
						return 'img/body/parasites/slime-tummy.png';
					default:
						return "";
				}
			},
			showfn(options) {
				return !!options.tummy_parasite
			},
			zfn(options) {
				if (options.crotch_exposed) return ZIndices.parasite;
				return ZIndices.underParasite;
			},
			dxfn(options) {
				if (options.belly >= 23) return 10;
				if (options.belly >= 22) return 8;
				if (options.belly >= 20) return 6;
				if (options.belly >= 15) return 4;
				if (options.belly >= 8) return 2;
				return 0;
			},
			dyfn(options) {
				if (options.belly >= 24) return 6;
				if (options.belly >= 8) return 4;
				if (options.belly >= 2) return 2;
				return 0;
			},
		},

		/***
		 *    ███████  █████   ██████ ███████
		 *    ██      ██   ██ ██      ██
		 *    █████   ███████ ██      █████
		 *    ██      ██   ██ ██      ██
		 *    ██      ██   ██  ██████ ███████
		 *
		 *
		 */
		"freckles": {
			filters: ["tan"],
			z: ZIndices.freckles,

			srcfn(options) {
				return `img/face/${options.facestyle}/freckles.png`;
			},
			showfn(options) {
				return options.show_face && !!options.freckles;
			},
		},
		"ears": {
			filters: ["tan"],
			z: ZIndices.ears,

			srcfn(options) {
				return `img/face/${options.facestyle}/ears.png`;
			},
			showfn(options) {
				return options.show_face && options.ears_position === "front";
			},
		},
		"eyes": {
			filters: ["tan"],
			z: ZIndices.eyes,

			srcfn(options) {
				return `img/face/${options.facestyle}/${options.facevariant}/eyes.png`;
			},
			showfn(options) {
				return options.show_face;
			},
		},
		"sclera": {
			z: ZIndices.sclera,

			srcfn(options) {
				return `img/face/${options.facestyle}/${options.facevariant}/${options.eyes_bloodshot ? "sclera-bloodshot" : "sclera"}.png`;
			},
			showfn(options) {
				return options.show_face;
			},
		},
		"left_iris": {
			filters: ["left_eye"],
			z: ZIndices.iris,
			animation: "idle",

			srcfn(options) {
				const iris = options.trauma ? "iris-empty" : "iris";
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/${iris}${half}.png`;
			},
			showfn(options) {
				return options.show_face;
			},
			masksrcfn(options) {
				return "img/face/masks/left.png"
			}
		},
		"right_iris": {
			filters: ["right_eye"],
			z: ZIndices.iris,
			animation: "idle",

			srcfn(options) {
				const iris = options.trauma ? "iris-empty" : "iris";
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/${iris}${half}.png`;
			},
			showfn(options) {
				return options.show_face;
			},
			masksrcfn(options) {
				return "img/face/masks/right.png"
			}
		},
		"eyelids": {
			show: true,
			filters: ["tan"],
			z: ZIndices.eyelids,

			srcfn(options) {
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/eyelids${half}.png`;
			},
			animationfn(options) {
				return options.blink_animation;
			},
		},
		"lashes": {
			filters: ["tan"],
			z: ZIndices.lashes,

			srcfn(options) {
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/lashes${half}.png`;
			},
			showfn(options) {
				return options.show_face;
			},
			animationfn(options) {
				return options.blink_animation;
			},
		},
		"makeup_eyeshadow": {
			filters: ["eyeshadow"],
			z: ZIndices.eyelids,

			brightnessfn(options) {
				makeupAdjustment(options);
				return options.makeup_adjustment;
			},

			srcfn(options) {
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/makeup/eyeshadow${half}.png`;
			},
			animationfn(options) {
				return options.blink_animation;
			},
			showfn(options) {
				return options.show_face && !!options.eyeshadow_colour;
			},
		},
		"makeup_mascara": {
			filters: ["mascara"],
			z: ZIndices.lashes,

			srcfn(options) {
				const half = options.eyes_half ? "-half-closed" : "";
				return `img/face/${options.facestyle}/${options.facevariant}/makeup/mascara${half}.png`;
			},
			animationfn(options) {
				return options.blink_animation;
			},
			showfn(options) {
				return options.show_face && !!options.mascara_colour;
			},
		},
		"makeup_blusher": {
			filters: ["tan"],
			z: ZIndices.blush + 1,

			srcfn(options) {
				return `img/face/${options.facestyle}/blusher.png`;
			},
			showfn(options) {
				return options.show_face && !!options.blusher_colour;
			},
		},
		"brows": {
			filters: ["brows"],
			z: ZIndices.brow,

			srcfn(options) {
				return `img/face/${options.facestyle}/${options.facevariant}/brow-${options.brows}.png`;
			},
			zfn(options) {
				return options.brows_position === "back" ? ZIndices.back_brow : ZIndices.brow;
			},
			showfn(options) {
				return options.show_face && options.brows !== "none";
			},
		},
		"mouth": {
			filters: ["tan"],
			z: ZIndices.mouth,

			srcfn(options) {
				return `img/face/${options.facestyle}/mouth-${options.mouth}.png`;
			},
			showfn(options) {
				return options.show_face && options.mouth !== "none";
			},
		},
		"makeup_lipstick": {
			filters: ["lipstick"],
			z: ZIndices.mouth,

			brightnessfn(options) {
				makeupAdjustment(options);
				return options.makeup_adjustment;
			},

			srcfn(options) {
				return `img/face/${options.facestyle}/lipstick-${options.mouth}.png`;
			},
			showfn(options) {
				return options.show_face && !!options.lipstick_colour;
			},
		},
		"blush": {
			filters: ["tan"],
			z: ZIndices.blush,

			srcfn(options) {
				return `img/face/${options.facestyle}/blush-${options.blush}.png`;
			},
			showfn(options) {
				return options.show_face && options.blush > 0;
			},
		},
		"tears": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/face/${options.facestyle}/tears-${options.tears}.png`;
			},
			showfn(options) {
				return options.show_face && options.tears > 0;
			},
		},
		"makeup_mascara_tears": {
			filters: ["mascara"],
			z: ZIndices.mascara_running,

			srcfn(options) {
				return `img/face/${options.facestyle}/${options.facevariant}/makeup/mascara${options.mascara_running}.png`;
			},
			showfn(options) {
				return options.show_face && options.mascara_running > 0 && !!options.mascara_colour;
			},
		},
		"toast": {
			filters: ["toast"],
			z: ZIndices.toast,

			srcfn() {
				return `img/clothes/props/food/toast-${V.trauma > 4000 ? "raw" : "buttered"}.png`;
			},
			showfn(options) {
				return options.show_face && !!options.toast;
			},
		},
		"scars": {
			z: ZIndices.neck,

			srcfn() {
				return 'img/body/scars-wraith.png';
			},
			showfn(options) {
				return options.show_face && options.scars;
			},
		},
		/***
		 *    ██   ██  █████  ██ ██████
		 *    ██   ██ ██   ██ ██ ██   ██
		 *    ███████ ███████ ██ ██████
		 *    ██   ██ ██   ██ ██ ██   ██
		 *    ██   ██ ██   ██ ██ ██   ██
		 *
		 *
		 */
		"hair_sides": {
			filters: ["hair"],
			animation: "idle",

			srcfn(options) {
				return `img/hair/sides/${options.hair_sides_type}/${options.hair_sides_length}.png`;
			},
			zfn(options) {
				return options.hair_sides_position === "front" ? ZIndices.hair_forward : ZIndices.backhair;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
				return `img/clothes/over-upper/kaiju/mask.png`;
				return options.headMask;
			},
			showfn(options) {
				return !!options.show_hair && !!options.hair_sides_type;
			},
		},
		"hair_fringe": {
			filters: ["hair_fringe"],
			z: ZIndices.front_hair,
			animation: "idle",

			srcfn(options) {
				return `img/hair/fringe/${options.hair_fringe_type}/${options.hair_fringe_length}.png`;
			},
			showfn(options) {
				return !!options.show_hair && !!options.hair_fringe_type;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
				return `img/clothes/over-upper/kaiju/mask.png`;
				return options.headMask.length ? options.headMask : options.fringe_mask_src;
			},
		},
		"hair_extra": { // Extra layer for thighs+ long hair for certain styles
			filters: ["hair"],
			z: ZIndices.backhair,
			animation: "idle",

			srcfn(options) {
				const hairs = [
					"default",
					"loose",
					"curl",
					"defined curl",
					"drill ringlets",
					"neat",
					"dreads",
					"afro pouf",
					"thick ponytail",
					"all down",
					"half up",
					"messy ponytail",
					"ruffled",
					"half up twintails",
					"princess wave",
					"space buns",
					"sleek",
					"bedhead",
					"classic",
					"cornrows",
					"french curls",
					"jellyfish bob",
					"princess ponytail"
				];

				const path = `img/hair/back/${options.hair_sides_type}`;
				if (options.hair_sides_length === "feet" && [...hairs, "straight"].includes(options.hair_sides_type))
					return `${path}/feet.png`;
				if (options.hair_sides_length === "thighs" && hairs.includes(options.hair_sides_type))
					return `${path}/thighs.png`;
				if (options.hair_sides_length === "navel" && options.hair_sides_type === "messy ponytail")
					return `${path}/navel.png`;
				return "";
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
				return `img/clothes/over-upper/kaiju/mask.png`;
				return options.headMask;
			},
			showfn(options) {
				return !!options.show_hair && !!options.hair_sides_type;
			},
		},
		/***
		 *     ██████ ██████   ██████  ████████  ██████ ██   ██
		 *    ██      ██   ██ ██    ██    ██    ██      ██   ██
		 *    ██      ██████  ██    ██    ██    ██      ███████
		 *    ██      ██   ██ ██    ██    ██    ██      ██   ██
		 *     ██████ ██   ██  ██████     ██     ██████ ██   ██
		 *
		 *
		 */
		"pbhair": {
			filters: ["pbhair"],
			z: ZIndices.pbhair,
			animation: "idle",

			srcfn(options) {
				return `img/hair/phair/pb${options.pbhair_level}.png`;
			},
			showfn(options) {
				// $pblevel 4 does not exist
				return options.crotch_visible
					&& options.pbhair_level > 1
					&& !options.belly_hides_under_lower
					&& options.pbhair_level !== 4;
			},
			masksrcfn(options) {
				return options.body_type === "soft" ? "img/clothes/masks/soft-lower-clip.png" : null;
			}
		},
		"pbhair_strip": {
			filters: ["pbhair"],
			z: ZIndices.pbhair,
			animation: "idle",

			srcfn(options) {
				return `img/hair/phair/pbstrip${options.pbhair_strip}.png`;
			},
			showfn(options) {
				return options.crotch_visible
					&& options.pbhair_strip >= 1
					&& !options.belly_hides_under_lower;
			},
			masksrcfn(options) {
				return options.body_type === "soft" ? "img/clothes/masks/soft-lower-clip.png" : null;
			}
		},
		"pbhair_balls": {
			filters: ["pbhair"],
			animation: "idle",

			zfn(options) {
				return options.crotch_exposed ? ZIndices.pbhairballs : ZIndices.pbhairballsunderclothes;
			},
			srcfn(options) {
				return `img/hair/phair/balls/${options.penis_size}-pb${options.pbhair_balls}.png`;
			},
			showfn(options) {
				return options.crotch_visible
					&& options.pbhair_balls > 1
					&& options.balls
					&& !options.genitals_chastity;
			},
		},
		"penis": {
			filters: ["tan"],
			animation: "idle",

			zfn(options) {
				if (!options.crotch_exposed) return ZIndices.penisunderclothes
				return (options.genitals_chastity) ? ZIndices.penis_chastity : ZIndices.penis
			},
			srcfn(options) {
				if (options.mannequin) return "img/body/mannequin/penis.png";
				if (options.genitals_chastity) return "img/body/penis/chastity.png";
				const penis = options.balls ? "penis" : "penis-no-balls";
				return `img/body/${penis}/${options.penis}.png`;
			},
			showfn(options) {
				return options.crotch_visible && !!options.penis && !playerHasStrapon() && !(options.ear_slime_panties && V.arousal < 6000);
			},
		},
		"penis_parasite": {
			animation: "idle",
			filtersfn(options) {
				if (options.ear_slime_panties) return ["ear_slime"];
				return [];
			},
			srcfn(options) {
				if (!options.penis_parasite.includes("ear-slime")) return `img/body/parasites/${options.penis_parasite}.png`;
				const folder = options.balls ? "penis" : "penis-no-balls";
				return `img/body/${folder}/${options.penis_parasite}.png`;
			},
			showfn(options) {
				return options.crotch_visible && !!options.penis && !!options.penis_parasite && !playerHasStrapon();
			},
			zfn(options) {
				if (options.genitals_chastity) return options.crotch_exposed ? ZIndices.penis_chastity : ZIndices.penisunderclothes;
				if (options.crotch_exposed) return ZIndices.parasite;
				return ZIndices.underParasite;
			},
		},
		"clit_parasite": {
			animation: "idle",

			srcfn(options) {
				return `img/body/${options.clit_parasite}.png`;
			},
			showfn(options) {
				return options.crotch_visible && !!options.clit_parasite && !options.chastity && !options.belly_hides_under_lower
			},
			zfn(options) {
				if (options.crotch_exposed) return ZIndices.parasite;
				return ZIndices.underParasite;
			},
		},
		"ear_slime_panties": {
			filters: ["ear_slime"],
			animation: "idle",

			srcfn(options) {
				return `img/body/${options.ear_slime_panties}.png`;
			},
			showfn(options) {
				return !!options.ear_slime_panties && !options.belly_hides_under_lower;
			},
			zfn(options) {
				return options.crotch_exposed ? ZIndices.penis_chastity - 0.1 : ZIndices.penisunderclothes - 0.1;
			},
		},
		"penis_condom": {
			alpha: 0.4,
			animation: "idle",
			filters: ["condom"],

			srcfn(options) {
				return options.penis_condom === 'plain' ? `img/body/penis/condom-${options.penis.replace("-virgin", "")}.png` : '';
			},
			showfn(options) {
				return options.crotch_visible
					&& !!options.penis
					&& !!options.penis_condom
					&& !options.genitals_chastity;
			},
			zfn(options) {
				return options.crotch_exposed ? ZIndices.parasite : ZIndices.underParasite;
			},
		},
		/***
		 *    ████████ ███████ ███████
		 *       ██    ██      ██
		 *       ██    █████   ███████
		 *       ██    ██           ██
		 *       ██    ██      ███████
		 *
		 *
		 */

		/***
		 *    ██     ██  ██████  ██      ███████
		 *    ██     ██ ██    ██ ██      ██
		 *    ██  █  ██ ██    ██ ██      █████
		 *    ██ ███ ██ ██    ██ ██      ██
		 *     ███ ███   ██████  ███████ ██
		 *
		 *
		 */
		"wolf_tail": genlayer_tail("wolf", true),
		"wolf_ears": genlayer_ears("wolf", true),
		"wolf_cheeks": genlayer_cheeks("wolf"),
		"wolf_pits": genlayer_tf_pits("wolf", "hirsute"),
		"wolf_pubes": genlayer_tf_pubes("wolf", "hirsute"),
		/***
		 *     ██████  █████  ████████
		 *    ██      ██   ██    ██
		 *    ██      ███████    ██
		 *    ██      ██   ██    ██
		 *     ██████ ██   ██    ██
		 *
		 *
		 */

		"cat_tail": genlayer_tail("cat", true),
		"cat_ears": genlayer_ears("cat", true),

		/***
		 *     ██████  ██████  ██     ██
		 *    ██      ██    ██ ██     ██
		 *    ██      ██    ██ ██  █  ██
		 *    ██      ██    ██ ██ ███ ██
		 *     ██████  ██████   ███ ███
		 *
		 *
		 */
		"cow_horns": genlayer_horns("cow", {
			zfn(options) {
				return options.cow_horns_layer === "front" ? ZIndices.over_head + 1 : ZIndices.horns + 1;
			},
		}),
		"cow_ear_left": genlayer_ears("cow", false, {
			z: ZIndices.horns,
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return "img/face/masks/left.png"
			}
		}),
		"cow_ear_right": genlayer_ears("cow", false, {
			zfn() {
				return ZIndices.ears + 0.5;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return "img/face/masks/right.png"
			}
		}),
		"cow_tag": genlayer_ears("cow", false, {
			z: ZIndices.facewear,
			src: `img/transformations/cow/ears/tag.png`,
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			}
		}),
		"cow_tail": genlayer_tail("cow", false),

		/***
		 *    ██████  ██ ██████  ██████
		 *    ██   ██ ██ ██   ██ ██   ██
		 *    ██████  ██ ██████  ██   ██
		 *    ██   ██ ██ ██   ██ ██   ██
		 *    ██████  ██ ██   ██ ██████
		 *
		 *
		 */

		"bird_wings_right": genlayer_wings("right", "bird", true),
		"bird_wings_left": genlayer_wings("left", "bird", true),
		"bird_wings_loose": {
			filters: ["hair"],
			animation: "looseFeathers",
			z: ZIndices.tailPenisCover,
			src: `img/transformations/bird/feathers/loose.png`,
			showfn(options) {
				return options.show_tf && isPartEnabled(options.bird_wings_type) && !options.hide_all && T.selfFeatherNum > 0;
			},
		},
		"bird_tail": genlayer_tail("bird", true),
		"bird_eyes": {
			z: ZIndices.irisacc,
			animation: "idle",

			srcfn(options) {
				return `img/transformations/bird/eyes/${options.bird_eyes_type}.png`;
			},
			showfn(options) {
				return options.show_tf
					&& options.show_face
					&& isPartEnabled(options.bird_eyes_type)
					&& !options.hide_all;
			},
			masksrcfn(options) {
				return {
					path: `img/face/${options.facestyle}/${options.facevariant}/iris.png`,
					convert: true,
				};
			}
		},
		"bird_malar": genlayer_tf("bird", "feathers", "malar"),
		"bird_plumage": genlayer_tf("bird", "feathers", "plumage"),
		"bird_pubes": genlayer_tf_pubes("bird", "feathers"),
		/***
		 *    ███████  ██████  ██   ██
		 *    ██      ██    ██  ██ ██
		 *    █████   ██    ██   ███
		 *    ██      ██    ██  ██ ██
		 *    ██       ██████  ██   ██
		 *
		 *
		 */
		"fox_tail": genlayer_tail("fox", true),
		"fox_ears": genlayer_ears("fox", true),
		"fox_cheeks": genlayer_cheeks("fox"),

		/***
		 *     █████  ███    ██  ██████  ███████ ██
		 *    ██   ██ ████   ██ ██       ██      ██
		 *    ███████ ██ ██  ██ ██   ███ █████   ██
		 *    ██   ██ ██  ██ ██ ██    ██ ██      ██
		 *    ██   ██ ██   ████  ██████  ███████ ███████
		 *
		 *
		 */
		"angel_wings_right": genlayer_wings("right", "angel", false),
		"angel_wings_left": genlayer_wings("left", "angel", false),
		"angel_halo_back": genlayer_halo("back", "angel"),
		"angel_halo_front": genlayer_halo("front", "angel"),
		/***
		 *    ███████  █████  ██      ██      ███████ ███    ██
		 *    ██      ██   ██ ██      ██      ██      ████   ██
		 *    █████   ███████ ██      ██      █████   ██ ██  ██
		 *    ██      ██   ██ ██      ██      ██      ██  ██ ██
		 *    ██      ██   ██ ███████ ███████ ███████ ██   ████
		 *
		 *
		 */
		"fallen_wings_right": genlayer_wings("right", "fallen", false),
		"fallen_wings_left": genlayer_wings("left", "fallen", false),
		"fallen_halo_back": genlayer_halo("back", "fallen"),
		"fallen_halo_front": genlayer_halo("front", "fallen"),

		/***
		 *    ██████  ███████ ███    ███  ██████  ███    ██
		 *    ██   ██ ██      ████  ████ ██    ██ ████   ██
		 *    ██   ██ █████   ██ ████ ██ ██    ██ ██ ██  ██
		 *    ██   ██ ██      ██  ██  ██ ██    ██ ██  ██ ██
		 *    ██████  ███████ ██      ██  ██████  ██   ████
		 *
		 *
		 */
		"demon_wings": {
			filters: ["demon_wings"],
			animation: "idle",

			srcfn(options) {
				return `img/transformations/demon/wings-${options.demon_wings_state}/${options.demon_wings_type}.png`;
			},
			showfn(options) {
				return options.show_tf
					&& isPartEnabled(options.demon_wings_type)
					&& !isPartEnabled(options.bird_wings_type)
					&& !options.hide_all;
			},
			zfn(options) {
				if (["cover", "flaunt"].includes(options.demon_wings_state)) return ZIndices.tailPenisCover
				if (options.demon_wings_layer === "back") return ZIndices.head_back;
				return ZIndices.backhair
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"demon_tail": genlayer_tail("demon", false, {
			filters: ["demon_tail"],
		}),
		"demon_horns": genlayer_horns("demon", {
			filters: ["demon_horns"],
		}),

		/***
		 *    ██     ██ ██████  ██ ████████ ██ ███    ██  ██████  ███████
		 *    ██     ██ ██   ██ ██    ██    ██ ████   ██ ██       ██
		 *    ██  █  ██ ██████  ██    ██    ██ ██ ██  ██ ██   ███ ███████
		 *    ██ ███ ██ ██   ██ ██    ██    ██ ██  ██ ██ ██    ██      ██
		 *     ███ ███  ██   ██ ██    ██    ██ ██   ████  ██████  ███████
		 *
		 *
		 */
		"writing_forehead": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPath('forehead', setup.bodywriting[options.writing_forehead]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_forehead;
			},
		},
		"writing_left_cheek": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPath('left_cheek', setup.bodywriting[options.writing_left_cheek]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_left_cheek;
			},
		},
		"writing_right_cheek": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPath('right_cheek', setup.bodywriting[options.writing_right_cheek]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_right_cheek;
			},
		},
		"writing_breasts": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				const area_name = "breasts"
				const writing = setup.bodywriting[options.writing_breasts];
				if (writing.type === "text") {
					if (writing.sprites && writing.sprites.length > 0 && writing.sprites.includes(area_name)) {
						return `img/bodywriting/text/${writing.key.replace(/_/g,"-")}/${area_name.replace(/_/g,"-")}.png`;
					}
					return `img/bodywriting/text/default/${area_name.replace(/_/g,"-")}-1.png`;
				}
				if (writing.type === "object") {
					return `img/bodywriting/${writing.writing}/${area_name.replace(/_/g,"-")}-${options.breast_size}.png`;
				}
				return '';
			},
			showfn(options) {
				return options.show_writings && !!options.writing_breasts;
			},
		},
		"writing_breasts_extra": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				const writing = setup.bodywriting[options.writing_breasts];
				if ((!writing.sprites || writing.sprites.length == 0)
					&& writing.type === "text" && options.breast_size >= 2) {
					return `img/bodywriting/text/default/breasts-${options.breast_size}.png`;
				}
				return '';
			},
			showfn(options) {
				return options.show_writings && !!options.writing_breasts;
			},
		},
		"writing_left_shoulder": {
			animation: "idle",

			srcfn(options) {
				return getWritingImgPath('left_shoulder', setup.bodywriting[options.writing_left_shoulder]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_left_shoulder;
			},
			zfn(options) {
				if (["cover", "hold"].includes(options.arm_left)) return ZIndices.left_cover_arm + 0.5;
				return ZIndices.breasts + 0.5;
			},
		},
		"writing_right_shoulder": {
			animation: "idle",

			srcfn(options) {
				return getWritingImgPath('right_shoulder', setup.bodywriting[options.writing_right_shoulder]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_right_shoulder;
			},
			dxfn(options) {
				if (["none", "cover"].includes(options.arm_right)) return 4;
				return 0;
			},
			zfn(options) {
				if (["cover", "hold"].includes(options.arm_right)) return ZIndices.right_cover_arm + 0.5;
				return ZIndices.armsidle + 0.5;
			},
		},
		"writing_pubic": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPathArrow('pubic', setup.bodywriting[options.writing_pubic]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_pubic;
			},
			dxfn(options) {
				if (options.belly >= 23) return 10;
				if (options.belly >= 22) return 8;
				if (options.belly >= 20) return 6;
				if (options.belly >= 17) return 4;
				if (options.belly >= 8) return 2;
				return 0;
			},
			dyfn(options) {
				if (options.belly >= 24) return 6;
				if (options.belly >= 22) return 4;
				if (options.belly >= 21) return 2;
				return 0;
			},
		},
		"writing_left_thigh": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPathArrow('left_thigh', setup.bodywriting[options.writing_left_thigh]);
			},
			showfn(options) {
				return options.show_writings && !!options.writing_left_thigh;
			},
		},
		"writing_right_thigh": {
			z: ZIndices.skin,
			animation: "idle",

			srcfn(options) {
				return getWritingImgPathArrow('right_thigh', setup.bodywriting[options.writing_right_thigh]);
			},
			showfn(options) {
				return !!options.writing_right_thigh;
			},
		},

		/***
		 *    ██████  ██████  ██ ██████  ███████
		 *    ██   ██ ██   ██ ██ ██   ██ ██
		 *    ██   ██ ██████  ██ ██████  ███████
		 *    ██   ██ ██   ██ ██ ██           ██
		 *    ██████  ██   ██ ██ ██      ███████
		 *
		 *
		 */

		"drip_vaginal": {
			z: ZIndices.tears,

			srcfn(options) {
				const output = options.drip_vaginal;
				return `img/body/cum/vaginal-${output}.png`;
			},
			showfn(options) {
				return !!options.drip_vaginal;
			},
			animationfn(options) {
				let anim = options.drip_vaginal;
				if (anim.includes("-")) {
					anim = toTitleCase(anim.split("-")[0]) + toTitleCase(anim.split("-")[1]);
				} else {
					anim = toTitleCase(anim);
				}
				return `VaginalCumDrip${anim}`;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"drip_anal": {
			z: ZIndices.tears,

			srcfn(options) {
				const output = options.drip_anal;
				return `img/body/cum/anal-${output}.png`;
			},
			showfn(options) {
				return !!options.drip_anal;
			},
			animationfn(options) {
				let anim = options.drip_anal;
				if (anim.includes("-")) {
					anim = toTitleCase(anim.split("-")[0]) + toTitleCase(anim.split("-")[1]);
				} else {
					anim = toTitleCase(anim);
				}
				return `AnalCumDrip${anim}`;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"drip_mouth": {
			z: ZIndices.semen_cough,

			srcfn(options) {
				const output = options.drip_mouth;
				return `img/body/cum/mouth-${output}.png`;
			},
			showfn(options) {
				return options.show_face
					&& !!options.drip_mouth
					&& !options.worn.face.setup.type.includesAny("face_covering");
			},
			dxfn(options) {
				return options.facestyle === "small-eyes" ? 2 : 0;
			},
			animationfn(options) {
				let anim = options.drip_mouth;
				if (anim.includes("-")) {
					anim = toTitleCase(anim.split("-")[0]) + toTitleCase(anim.split("-")[1]);
				} else {
					anim = toTitleCase(anim);
				}
				return `MouthCumDrip${anim}`;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_chest": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/chest-${options.cum_chest}.png`;
			},
			showfn(options) {
				return !!options.cum_chest;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_face": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/face-${options.cum_face}.png`;
			},
			showfn(options) {
				return options.show_face && !!options.cum_face;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_feet": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/feet-${options.cum_feet}.png`;
			},
			showfn(options) {
				return !!options.cum_feet;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_leftarm": {
			animation: "idle",
			srcfn(options) {
				return `img/body/cum/left-arm-${options.cum_leftarm}.png`;
			},
			showfn(options) {
				return options.arm_left !== "none" && options.arm_left != "cover" && !!options.cum_leftarm;
			},
			zfn(options) {
				return (options.arm_right === "cover") ? ZIndices.arms_cover + 0.05 : options.zarms + 0.05;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_rightarm": {
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/right-arm-${options.cum_rightarm}.png`;
			},
			showfn(options) {
				return options.arm_right !== "none"
					&& options.arm_right != "cover"
					&& options.arm_right != "hold"
					&& !!options.cum_rightarm;
			},
			zfn(options) {
				return (options.arm_right === "cover" || options.arm_right === "hold") ? ZIndices.arms_cover + 0.05 : options.zarms + 0.05;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_neck": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/neck-${options.cum_neck}.png`;
			},
			showfn(options) {
				return !!options.cum_neck;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_thigh": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/thighs-${options.cum_thigh}.png`;
			},
			showfn(options) {
				return !!options.cum_thigh;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},
		"cum_tummy": {
			z: ZIndices.tears,
			animation: "idle",

			srcfn(options) {
				return `img/body/cum/tummy-${options.cum_tummy}.png`;
			},
			showfn(options) {
				return !!options.cum_tummy;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
			},
		},

		/***
		 *     ██████ ██       ██████  ████████ ██   ██ ███████ ███████
		 *    ██      ██      ██    ██    ██    ██   ██ ██      ██
		 *    ██      ██      ██    ██    ██    ███████ █████   ███████
		 *    ██      ██      ██    ██    ██    ██   ██ ██           ██
		 *     ██████ ███████  ██████     ██    ██   ██ ███████ ███████
		 *
		 *
		 */
		/***
		 *    ██    ██ ██████  ██████  ███████ ██████
		 *    ██    ██ ██   ██ ██   ██ ██      ██   ██
		 *    ██    ██ ██████  ██████  █████   ██████
		 *    ██    ██ ██      ██      ██      ██   ██
		 *     ██████  ██      ██      ███████ ██   ██
		 *
		 *
		 */
		"upper_main": genlayer_clothing_main('upper', {
			zfn(options) {
				return options.worn.upper.setup.name === "cocoon" ? ZIndices.old_over_upper : options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upperMask;
			},
		}),
		"upper_detail": genlayer_clothing_detail('upper', {
			zfn(options) {
				return options.zupper;
			},
		}),
		"upper_fitted_left": genlayer_clothing_fitted_left("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"upper_fitted_right": genlayer_clothing_fitted_right("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"upper_belly_split_shadow": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper - 1;
			},
			masksrcfn(options) {
				return options.shirt_mask_clip_src;
			},
			dyfn(options) {
				return options.shirt_move_left_src ? 2 : 0;
			},
			dxfn() {
				return 0;
			},
			brightnessfn(options) {
				return options.shirt_move_left_src && options.shirt_mask_clip_src ? -0.3 : 0;
			},
		}),
		"upper_belly_split_l": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_left_src;
			},
			dxfn(options) {
				if (options.shirt_move_left_src)
					return options.belly >= 22 ? 12 : 8;
				return 0;
			},
			dyfn(options) {
				return options.shirt_move_left_src ? -2 : 0;
			},
		}),
		"upper_belly_split_l2": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_left2_src;
			},
			dxfn(options) {
				if (options.shirt_move_left2_src)
					return options.belly >= 22 ? 14 : 10;
				return 0;
			},
			dyfn() {
				return 0;
			},
		}),
		"upper_belly_split_l_shadow": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper - 1;
			},
			masksrcfn(options) {
				return options.shirt_move_left_src
			},
			dxfn(options) {
				if (options.shirt_move_left_src)
					return options.belly >= 22 ? 14 : 10;
				return 0;
			},
			dyfn(options) {
				return options.shirt_move_left_src ? -2 : 0;
			},
			brightnessfn(options) {
				return options.shirt_move_left_src ? -0.3 : 0;
			},
		}),
		"upper_belly_split_l2_shadow": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper - 1;
			},
			masksrcfn(options) {
				return options.shirt_move_left2_src;
			},
			dxfn(options) {
				if (options.shirt_move_left2_src)
					return options.belly >= 22 ? 16 : 12;
				return 0;
			},
			dyfn() {
				return 0;
			},
			brightnessfn(options) {
				return options.shirt_move_left2_src ? -0.3 : 0;
			},
		}),
		"upper_belly_split_r": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right_src;
			},
		}),
		"upper_belly_split_r2": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right2_src;
			},
			dxfn(options) {
				if (options.shirt_move_right2_src) return -4;
			},
		}),
		"upper_belly_split_r3": genlayer_clothing_belly_split("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right3_src;
			},
			dxfn(options) {
				if (options.shirt_move_right3_src) return -6;
			},
		}),
		"upper_belly_2": genlayer_clothing_belly_2("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.belly_mask_src;
			},
		}),
		"upper_belly": genlayer_clothing_belly("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.belly_mask_src;
			},
		}),
		"upper_belly_acc": genlayer_clothing_belly_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.belly_mask_src;
			},
		}),
		"upper_belly_split_acc_shadow": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper - 1;
			},
			masksrcfn(options) {
				return options.shirt_mask_clip_src;
			},
			dyfn(options) {
				return options.shirt_move_left_src ? 2 : 0;
			},
			dxfn() {
				return 0;
			},
			brightnessfn(options) {
				return options.shirt_move_left_src && options.shirt_mask_clip_src ? -0.3 : 0;
			},
		}),
		"upper_belly_split_acc_l": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_left_src;
			},
			dxfn(options) {
				if (options.shirt_move_left_src) return options.belly >= 22 ? 12 : 10;
				return 0;
			},
			dyfn(options) {
				return options.shirt_move_left_src ? -4 : 0;
			},
		}),
		"upper_belly_split_acc_l2": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_left2_src;
			},
			dxfn(options) {
				if (options.shirt_move_left2_src) return options.belly >= 22 ? 14 : 12;
				return 0;
			},
			dyfn(options) {
				return options.shirt_move_left2_src ? -2 : 0;
			},
		}),
		"upper_belly_split_acc_r": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right_src;
			},
		}),
		"upper_belly_split_acc_r2": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right2_src;
			},
			dxfn(options) {
				if (options.shirt_move_right2_src) return -4;
			},
		}),
		"upper_belly_split_acc_r3": genlayer_clothing_belly_split_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				return options.shirt_move_right3_src;
			},
			dxfn(options) {
				if (options.shirt_move_right3_src) return -6;
			},
		}),
		"upper_fitted_left_acc": genlayer_clothing_fitted_left_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"upper_fitted_right_acc": genlayer_clothing_fitted_right_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"upper_breasts": genlayer_clothing_breasts("upper", {
			zfn(options) {
				return options.acc_layer_under ? ZIndices.upper + 1 : options.zupper;
			},
		}),
		"upper_acc": genlayer_clothing_accessory("upper", {
			zfn(options) {
				return options.arm_right === "hold" && options.sleeve_over_hold ? ZIndices.lower_high : options.zupper;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.upperMask;
			},
		}),
		"upper_breasts_acc": genlayer_clothing_breasts_acc("upper", {
			zfn(options) {
				return options.zupper;
			},
		}),
		"upper_breasts_detail": genlayer_clothing_breasts_detail("upper", {
			zfn(options) {
				return options.zupper;
			},
		}),
		"upper_rightarm": genlayer_clothing_arm("right", "upper", {
			zfn(options) {
				return options.zupperright;
			},
		}),
		"upper_leftarm": genlayer_clothing_arm("left", "upper", {
			zfn(options) {
				return options.zupperleft;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.belly_hides_lower ? options.belly_mask_clip_src : null;
			},
		}),
		"upper_leftarm_fitted": genlayer_clothing_arm_fitted("left", "upper", {
			zfn(options) {
				return options.zupperleft - 1;
			},
		}),
		"upper_leftarm_fitted_acc": genlayer_clothing_arm_acc_fitted("left", "upper", {
			zfn(options) {
				return options.zupperleft - 1;
			},
		}),
		"upper_rightarm_acc": genlayer_clothing_arm_acc("right", "upper", {
			zfn(options) {
				return options.zupperright;
			},
		}),
		"upper_leftarm_acc": genlayer_clothing_arm_acc("left", "upper", {
			zfn(options) {
				return options.zupperleft;
			},
		}),
		"upper_back": genlayer_clothing_back_img('upper', {
			z: ZIndices.back_lower
		}),

		/***
		 *     ██████  ██    ██ ███████ ██████  ██    ██ ██████  ██████  ███████ ██████
		 *    ██    ██ ██    ██ ██      ██   ██ ██    ██ ██   ██ ██   ██ ██      ██   ██
		 *    ██    ██ ██    ██ █████   ██████  ██    ██ ██████  ██████  █████   ██████
		 *    ██    ██  ██  ██  ██      ██   ██ ██    ██ ██      ██      ██      ██   ██
		 *     ██████    ████   ███████ ██   ██  ██████  ██      ██      ███████ ██   ██
		 *
		 *
		 */
		"over_upper_main": genlayer_clothing_main('over_upper'),
		"over_upper_breasts": genlayer_clothing_breasts("over_upper"),
		"over_upper_acc": genlayer_clothing_accessory('over_upper'),
		"over_upper_detail": genlayer_clothing_detail('over_upper'),
		"over_upper_rightarm": genlayer_clothing_arm("right", "over_upper", {
			zfn(options) {
				return (options.arm_right === "cover" || options.arm_right === "hold") ?
					ZIndices.over_upper_arms + 0.9 : ZIndices.over_upper_arms;
			},
		}),
		"over_upper_leftarm": genlayer_clothing_arm("left", "over_upper", {
			zfn(options) {
				return options.arm_left === "cover" ?
					ZIndices.over_upper_arms + 0.9 : ZIndices.over_upper_arms;
			},
		}),
		"over_upper_back": genlayer_clothing_back_img('over_upper', {
			z: ZIndices.back_lower - 10
		}),
		/***
		 *     ██████  ███████ ███    ██ ██ ████████  █████  ██      ███████
		 *    ██       ██      ████   ██ ██    ██    ██   ██ ██      ██
		 *    ██   ███ █████   ██ ██  ██ ██    ██    ███████ ██      ███████
		 *    ██    ██ ██      ██  ██ ██ ██    ██    ██   ██ ██           ██
		 *     ██████  ███████ ██   ████ ██    ██    ██   ██ ███████ ███████
		 *
		 *
		 */

		"genitals": genlayer_clothing_main('genitals', {
			zfn(options) {
				return options.crotch_exposed ? ZIndices.penis_chastity + 0.1 : ZIndices.penisunderclothes + 0.1;
			},
			showfn(options) {
				return options.worn.genitals.index > 0
					&& options.worn.genitals.setup.mainImage !== 0
					&& !options.worn.genitals.setup.hideUnderLower.includes(options.worn.under_lower.setup.name)
					&& !options.belly_hides_under_lower;
			},
			srcfn(options) {
				if (options.worn.genitals.setup.name === "chastity parasite") {
					return `img/body/ear-slime-chastity-${options.ear_slime_size}.png`;
				}

				const setupVar = options.worn.genitals.setup.variable;
				const integrity = options.worn.genitals.integrity;
				return `img/clothes/genitals/${setupVar}/${integrity}.png`;
			},
			masksrcfn(options) {
				return options.underLowerMask;
			}
		}),
		"buttplug": {
			z: ZIndices.backhair,
			animation: "idle",
			showfn(options) {
				return playerHasButtPlug() && V.worn.butt_plug.name.includes("tail") && !options.mannequin;
			},
			srcfn() {
				return `img/clothes/back/${V.worn.butt_plug.name}/back.png`;
			},
		},
		/***
		 *    ██       ██████  ██     ██ ███████ ██████
		 *    ██      ██    ██ ██     ██ ██      ██   ██
		 *    ██      ██    ██ ██  █  ██ █████   ██████
		 *    ██      ██    ██ ██ ███ ██ ██      ██   ██
		 *    ███████  ██████   ███ ███  ███████ ██   ██
		 *
		 *
		 */
		"lower": genlayer_clothing_main('lower', {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const secondary = options.worn.lower.setup.type.includes("overalls") ? ZIndices.lower_cover : ZIndices.lower;
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : secondary;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.lowerMask;
			},
		}),
		"lower_belly_2": genlayer_clothing_belly_2("lower", {
			masksrcfn(options) {
				return options.lowerBellyMask;
			},
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : ZIndices.lower_belly;
			},
		}),
		"lower_belly": genlayer_clothing_belly("lower", {
			masksrcfn(options) {
				return options.lowerBellyMask;
			},
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : ZIndices.lower_belly;
			},
		}),
		"lower_belly_shadow": genlayer_clothing_belly_shadow("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : ZIndices.lower_belly;
			},
		}),
		"lower_belly_acc": genlayer_clothing_belly_acc("lower", {
			masksrcfn(options) {
				return options.lowerBellyMask;
			},
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : ZIndices.lower_belly;
			},
		}),
		"lower_breasts": genlayer_clothing_breasts("lower", {
			zfn(options) {
				return options.acc_layer_under ? ZIndices.lower_high + 1 : ZIndices.lower_high;
			},
		}),
		"lower_fitted_left": genlayer_clothing_fitted_left("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const secondary = options.worn.lower.setup.type.includes("overalls") ? ZIndices.lower_cover : ZIndices.lower;
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : secondary;
			},
			masksrcfn(options) {
				return options.upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"lower_fitted_right": genlayer_clothing_fitted_right("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const secondary = options.worn.lower.setup.type.includes("overalls") ? ZIndices.lower_cover : ZIndices.lower;
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : secondary;
			},
			masksrcfn(options) {
				return options.upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"lower_fitted_acc_left": genlayer_clothing_fitted_left_acc("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const secondary = options.worn.lower.setup.type.includes("overalls") ? ZIndices.lower_cover : ZIndices.lower;
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : secondary;
			},
			masksrcfn(options) {
				return options.upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"lower_fitted_acc_right": genlayer_clothing_fitted_right_acc("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const secondary = options.worn.lower.setup.type.includes("overalls") ? ZIndices.lower_cover : ZIndices.lower;
				return options.worn.lower.setup.high_img ? ZIndices.lower_high : secondary;
			},
			masksrcfn(options) {
				return options.upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"lower_acc": genlayer_clothing_accessory("lower", {
			srcfn(options) {
				const secondary = options.worn.upper.setup.name === "school blouse" && options.worn.lower.setup.name.includes("pinafore") ? '-under' : '';
				const suffix = options.worn.lower.setup.accessory_integrity_img ? `-${options.worn.lower.integrity}` : secondary;
				const pattern = options.worn.lower.pattern && options.worn.lower.setup.pattern_layer === "secondary" ? "-" + options.worn.lower.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/lower/${options.worn.lower.setup.variable}/acc${suffix}${pattern}.png`;
			},
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				if (options.worn.lower.setup.name.includes("ballgown") || options.worn.lower.setup.name.includes("pinafore"))
					return ZIndices.upper_top;
				if (options.worn.lower.setup.type.includes("overalls")) return ZIndices.lower_cover;
				return ZIndices.lower;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.lowerMask;
			},
		}),
		"lower_detail": genlayer_clothing_detail("lower", {
			zfn(options) {
				const setup = options.worn.lower.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				if (options.worn.lower.setup.type.includes("overalls"))
					return ZIndices.lower_high;
				return ZIndices.lower;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				return options.lowerMask;
			},
		}),
		"lower_breasts_acc": genlayer_clothing_breasts_acc("lower", {
			zfn(options) {
				return options.acc_layer_under ? ZIndices.lower_high + 1 : ZIndices.lower_high;
			},
		}),
		"lower_penis": {
			z: ZIndices.lower_top,
			filters: ["worn_lower"],
			animation: "idle",

			//ToDo: add images for lower penis bulges. check against pregnancy belly
			srcfn(options) {
				return `img/clothes/lower/${options.worn.lower.setup.variable}/penis.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& !options.belly_hides_lower
					&& options.worn.lower.index > 0
					&& options.worn.lower.setup.penis_img === 1
					&& calculatePenisBulge() - 6 > 0;
			},
		},
		"lower_penis_acc": {
			z: ZIndices.lower_top,
			filters: ["worn_lower_acc"],
			animation: "idle",

			//ToDo: add images for lower penis bulges. check against pregnancy belly
			srcfn(options) {
				return `img/clothes/lower/${options.worn.lower.setup.variable}/acc-penis.png`
			},
			showfn(options) {
				return options.show_clothes
					&& !options.belly_hides_lower
					&& options.worn.lower.index > 0
					&& options.worn.lower.setup.penis_acc_img === 1
					&& options.worn.lower.setup.accessory === 1
					&& calculatePenisBulge() - 6 > 0;
			},
		},
		"lower_back": genlayer_clothing_back_img('lower', {
			z: ZIndices.back_lower
		}),
		"lower_back_acc": genlayer_clothing_back_img_acc('lower', {
			z: ZIndices.back_lower
		}),
		/***
		 *     ██████  ██    ██ ███████ ██████  ██       ██████  ██     ██ ███████ ██████
		 *    ██    ██ ██    ██ ██      ██   ██ ██      ██    ██ ██     ██ ██      ██   ██
		 *    ██    ██ ██    ██ █████   ██████  ██      ██    ██ ██  █  ██ █████   ██████
		 *    ██    ██  ██  ██  ██      ██   ██ ██      ██    ██ ██ ███ ██ ██      ██   ██
		 *     ██████    ████   ███████ ██   ██ ███████  ██████   ███ ███  ███████ ██   ██
		 *
		 *
		 */
		"over_lower": genlayer_clothing_main('over_lower'),
		"over_lower_acc": genlayer_clothing_accessory('over_lower'),
		"over_lower_detail": genlayer_clothing_detail('over_lower'),
		"over_lower_back": genlayer_clothing_back_img('over_lower'),
		/***
		 *    ██    ██ ███    ██ ██████  ███████ ██████  ██       ██████  ██     ██ ███████ ██████
		 *    ██    ██ ████   ██ ██   ██ ██      ██   ██ ██      ██    ██ ██     ██ ██      ██   ██
		 *    ██    ██ ██ ██  ██ ██   ██ █████   ██████  ██      ██    ██ ██  █  ██ █████   ██████
		 *    ██    ██ ██  ██ ██ ██   ██ ██      ██   ██ ██      ██    ██ ██ ███ ██ ██      ██   ██
		 *     ██████  ██   ████ ██████  ███████ ██   ██ ███████  ██████   ███ ███  ███████ ██   ██
		 *
		 *
		 */
		"under_lower": genlayer_clothing_main('under_lower', {
			zfn(options) {
				return options.worn.lower.setup.high_img ?
					ZIndices.under_lower_high : ZIndices.under_lower;
			},
			masksrcfn(options) {
				return options.underLowerMask;
			},
		}),
		"under_lower_belly_2": genlayer_clothing_belly_2("under_lower", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn(options) {
				return options.worn.lower.setup.high_img ?
					ZIndices.under_lower_high : ZIndices.under_lower;
			},
			showfn(options) {
				return options.belly > 7
					&& options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.mainImage !== 0;
			},
		}),
		"under_lower_belly": genlayer_clothing_belly("under_lower", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn(options) {
				return options.worn.lower.setup.high_img ?
					ZIndices.under_lower_high : ZIndices.under_lower;
			},
			showfn(options) {
				return options.belly > 7
					&& options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.mainImage !== 0;
			},
		}),
		"under_lower_belly_shadow": genlayer_clothing_belly_shadow("under_lower", {
			zfn() {
				return ZIndices.under_lower_top_high;
			},
			showfn(options) {
				return (options.belly > 7 || (options.body_type === "soft" && !options.worn.under_upper.setup.outfitPrimary))
					&& options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.mainImage !== 0;
			},
		}),
		"under_lower_belly_acc": genlayer_clothing_belly_acc("under_lower", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn(options) {
				return options.worn.lower.setup.high_img ?
					ZIndices.under_lower_high : ZIndices.under_lower;
			},
			showfn(options) {
				return options.belly > 7
					&& options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.accessory === 1;
			},
		}),
		"under_lower_acc": genlayer_clothing_accessory("under_lower", {
			masksrcfn(options) {
				return options.underLowerMask;
			},
		}),
		"under_lower_detail": genlayer_clothing_detail("under_lower", {
			masksrcfn(options) {
				return options.underLowerMask;
			},
		}),
		"under_lower_penis": {
			z: ZIndices.under_lower_top,
			filters: ["worn_under_lower"],
			animation: "idle",

			//ToDo: expand the existing bulk images by providing a small bulge when `calculatePenisBulge()` is less than 8 (max is 15). check against pregnancy belly
			srcfn(options) {
				return `img/clothes/under-lower/${options.worn.under_lower.setup.variable}/penis.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.penis_img === 1
					&& calculatePenisBulge() > 0;
			},
			masksrcfn(options) {
				return options.underLowerMask;
			},
		},
		"under_lower_penis_acc": {
			z: ZIndices.under_lower_top,
			filters: ["worn_under_lower_acc"],
			animation: "idle",

			//ToDo: expand the existing bulk images by providing a small bulge when `calculatePenisBulge()` is less than 8 (max is 15). check against pregnancy belly
			srcfn(options) {
				return `img/clothes/under-lower/${options.worn.under_lower.setup.variable}/acc-penis.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& !options.belly_hides_under_lower
					&& options.worn.under_lower.index > 0
					&& options.worn.under_lower.setup.penis_acc_img === 1
					&& options.worn.under_lower.setup.accessory === 1
					&& calculatePenisBulge() > 0;
			},
			masksrcfn(options) {
				return options.underLowerMask;
			},
		},
		/***
		 *    ██    ██ ███    ██ ██████  ███████ ██████  ██    ██ ██████  ██████  ███████ ██████
		 *    ██    ██ ████   ██ ██   ██ ██      ██   ██ ██    ██ ██   ██ ██   ██ ██      ██   ██
		 *    ██    ██ ██ ██  ██ ██   ██ █████   ██████  ██    ██ ██████  ██████  █████   ██████
		 *    ██    ██ ██  ██ ██ ██   ██ ██      ██   ██ ██    ██ ██      ██      ██      ██   ██
		 *     ██████  ██   ████ ██████  ███████ ██   ██  ██████  ██      ██      ███████ ██   ██
		 *
		 *
		 */
		"under_upper": genlayer_clothing_main('under_upper', {
			masksrcfn(options) {
				if (options.belly >= 19 && options.worn.upper.setup.pregType == "split")
					return options.worn.under_upper.setup.pregType === "split"
						&& options.shirt_mask_clip_src;

				return options.underUpperMask;
			}
		}),
		"under_upper_fitted_left": genlayer_clothing_fitted_left("under_upper", {
			masksrcfn(options) {
				return options.under_upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"under_upper_fitted_right": genlayer_clothing_fitted_right("under_upper", {
			masksrcfn(options) {
				return options.under_upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"under_upper_fitted_left_acc": genlayer_clothing_fitted_left_acc("under_upper", {
			masksrcfn(options) {
				return options.under_upper_fitted_left_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? 2 : -2;
			},
		}),
		"under_upper_fitted_right_acc": genlayer_clothing_fitted_right_acc("under_upper", {
			masksrcfn(options) {
				return options.under_upper_fitted_right_move_src;
			},
			dxfn(options) {
				return options.body_type === "soft" ? -2 : 2;
			},
		}),
		"under_upper_belly_2": genlayer_clothing_belly_2("under_upper", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn() {
				return ZIndices.under_upper_top;
			},
		}),
		"under_upper_belly": genlayer_clothing_belly("under_upper", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn() {
				return ZIndices.under_upper_top;
			},
		}),
		"under_upper_belly_acc": genlayer_clothing_belly_acc("under_upper", {
			masksrcfn(options) {
				return options.belly_mask_src;
			},
			zfn(options) {
				return options.worn.lower.setup.high_img ?
					ZIndices.under_upper_top_acc : ZIndices.under_upper_top_acc;
			},
		}),
		"under_upper_breasts": genlayer_clothing_breasts("under_upper"),
		"under_upper_acc": genlayer_clothing_accessory('under_upper', {
			masksrcfn(options) {
				if (options.belly >= 19 && options.worn.upper.setup.pregType == "split")
					return options.worn.under_upper.setup.pregType === "split"
						&& options.shirt_mask_clip_src;

				if (!(options.worn.under_upper.setup.formfittingDisabled ?? []).includes("acc"))
				return options.underUpperMask;
			}
		}),
		"under_upper_breasts_acc": genlayer_clothing_breasts_acc('under_upper'),
		"under_upper_breasts_detail": genlayer_clothing_breasts_detail("under_upper"),
		"under_upper_back": genlayer_clothing_back_img('under_upper'),
		"under_upper_rightarm": genlayer_clothing_arm("right", "under_upper", {
			zfn(options) {
				return options.arm_right === "cover" || options.arm_right === "hold" ?
					options.zupperright - 1 : ZIndices.under_upper_arms;
			},
		}),
		"under_upper_leftarm": genlayer_clothing_arm("left", "under_upper", {
			zfn(options) {
				return options.arm_left === "cover" ? options.zupperleft - 1 : ZIndices.under_upper_arms;
			},
		}),
		"under_upper_leftarm_fitted": genlayer_clothing_arm_fitted("left", "under_upper", {
			zfn() {
				return ZIndices.under_upper_arms - 0.1;
			},
		}),
		"under_upper_leftarm_fitted_acc": genlayer_clothing_arm_acc_fitted("left", "under_upper", {
			zfn() {
				return ZIndices.under_upper_arms - 0.1;
			},
		}),
		"under_upper_rightarm_acc": genlayer_clothing_arm_acc("right", "under_upper", {
			zfn(options) {
				return options.arm_right === "cover" || options.arm_right === "hold" ?
					options.zupperright - 1 : ZIndices.under_upper_arms;
			},
		}),
		"under_upper_leftarm_acc": genlayer_clothing_arm_acc("left", "under_upper", {
			zfn(options) {
				return options.arm_left === "cover" ? options.zupperleft - 1 : ZIndices.under_upper_arms;
			},
		}),
		/***
		 *    ██   ██  █████  ███    ██ ██████  ███████
		 *    ██   ██ ██   ██ ████   ██ ██   ██ ██
		 *    ███████ ███████ ██ ██  ██ ██   ██ ███████
		 *    ██   ██ ██   ██ ██  ██ ██ ██   ██      ██
		 *    ██   ██ ██   ██ ██   ████ ██████  ███████
		 *
		 *
		 */
		"hands": genlayer_clothing_main('hands'),
		"hands_left": {
			filters: ["worn_hands"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && !["tertiary", "secondary"].includes(options.worn.hands.setup.pattern_layer) ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/hands/${options.worn.hands.setup.variable}/left-${options.arm_left}${pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.leftImage === 1
					&& options.arm_left !== "none";
			},
			zfn(options) {
				return options.arm_left === "cover" ? options.zupperleft - 0.5 : options.zarms + 0.2;
			},
		},
		"hands_left_acc": {
			filters: ["worn_hands_acc"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && options.worn.hands.setup.pattern_layer === "secondary" ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/hands/${options.worn.hands.setup.variable}/left-${options.arm_left}${pattern}-acc.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.leftImage === 1
					&& options.worn.hands.setup.accessory === 1
					&& options.arm_left !== "none";
			},
			zfn(options) {
				return options.arm_left === "cover" ? options.zupperleft - 0.5 : options.zarms + 0.2;
			},
		},
		"hands_left_fitted": {
			filters: ["worn_hands"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && !["tertiary", "secondary"].includes(options.worn.hands.setup.pattern_layer) ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/hands/${options.worn.hands.setup.variable}/left-${options.arm_left}${pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.leftImage === 1
					&& ["curvy", "slender"].includes(options.body_type)
					&& options.arm_left === "idle"
					&& !(options.belly > 7)
			},
			masksrcfn(options) {
				return options.upper_fitted_left_move_src || options.under_upper_fitted_left_move_src ;
			},
			dxfn() {
				return -2;
			},
			zfn(options) {
				return options.zarms + 0.1;
			},
		},
		"hands_left_fitted_acc": {
			filters: ["worn_hands_acc"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && options.worn.hands.setup.pattern_layer === "secondary" ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/hands/${options.worn.hands.setup.variable}/left-${options.arm_left}${pattern}-acc.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.leftImage === 1
					&& options.worn.hands.setup.accessory === 1
					&& ["curvy", "slender"].includes(options.body_type)
					&& options.arm_left === "idle"
					&& !(options.belly > 7);
			},
			masksrcfn(options) {
				return options.upper_fitted_left_move_src || options.under_upper_fitted_left_move_src;
			},
			dxfn() {
				return -2;
			},
			zfn(options) {
				return options.zarms + 0.1;
			},
		},
		"hands_left_detail": {
			animation: "idle",

			srcfn(options) {
				return `img/clothes/hands/${options.worn.hands.setup.variable}/left-${options.arm_left}-${options.worn.hands.pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.leftImage === 1
					&& options.worn.hands.setup.pattern_layer === "tertiary"
					&& !!options.worn.hands.setup.pattern
					&& options.arm_right !== "none";
			},
			zfn(options) {
				return (options.arm_right === "cover" || options.arm_right === "hold") ?
					ZIndices.hands : options.zarms + 0.2;
			},
		},
		"hands_right": {
			filters: ["worn_hands"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && !["tertiary", "secondary"].includes(options.worn.hands.setup.pattern_layer) ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/hands/${options.worn.hands.setup.variable}/right-${options.arm_right}${pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.rightImage === 1
					&& options.arm_right !== "none";
			},
			zfn(options) {
				return ["cover", "hold"].includes(options.arm_right) ? options.zupperright - 0.5 : options.zarms + 0.2;
			},
		},
		"hands_right_acc": {
			filters: ["worn_hands_acc"],
			animation: "idle",

			srcfn(options) {
				const pattern = options.worn.hands.pattern && options.worn.hands.setup.pattern_layer === "secondary" ? "-" + options.worn.hands.pattern?.replace(/ /g,"-") : '';
				return`img/clothes/hands/${options.worn.hands.setup.variable}/right-${options.arm_right}${pattern}-acc.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.rightImage === 1
					&& options.worn.hands.setup.accessory === 1
					&& options.arm_right !== "none";
			},
			zfn(options) {
				return ["cover", "hold"].includes(options.arm_right) ? options.zupperright - 0.5 : options.zarms + 0.2;
			},
		},
		"hands_right_detail": {
			animation: "idle",

			srcfn(options) {
				return `img/clothes/hands/${options.worn.hands.setup.variable}/right-${options.arm_right}-${options.worn.hands.pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.hands.index > 0
					&& options.worn.hands.setup.rightImage === 1
					&& options.worn.hands.setup.pattern_layer === "tertiary"
					&& !!options.worn.hands.setup.pattern
					&& options.arm_right !== "none";
			},
			zfn(options) {
				return (options.arm_right === "cover" || options.arm_right === "hold") ?
					ZIndices.hands : options.zarms + 0.2;
			},
		},
		/***
		 *    ██   ██  █████  ███    ██ ██████  ██   ██ ██████ ██     ██████
		 *    ██   ██ ██   ██ ████   ██ ██   ██ ██   ██ ██     ██     ██   ██
		 *    ███████ ███████ ██ ██  ██ ██   ██ ███████ ██████ ██     ██   ██
		 *    ██   ██ ██   ██ ██  ██ ██ ██   ██ ██   ██ ██     ██     ██   ██
		 *    ██   ██ ██   ██ ██   ████ ██████  ██   ██ ██████ ██████ ██████
		 *
		 *
		 */
		"handheld_right": genlayer_clothing_main('handheld', {
			srcfn(options) {
				const pattern = options.worn.handheld.pattern && !["tertiary", "secondary"].includes(options.worn.handheld.setup.pattern_layer) ? "-" + options.worn.handheld.pattern?.replace(/ /g,"-") : '';

				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/right-${options.arm_right}${pattern}.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_right === "none" || (options.prop && options.prop.armPosition !== "handsfree")) return false;

				if (options.arm_right === "cover") return options.worn.handheld.setup.coverImage !== 0;
				return true;
			},
			zfn(options) {
				const setup = options.worn.handheld.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				if (options.arm_right === "cover") return ZIndices.arms_cover;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
			animationfn(options) {
				return options.handheld_animation
			},
			filtersfn(options) {
				if (["feather"].includes(options.worn.handheld.setup.variable) && options.worn.handheld.colour === "grey") {
					return ["hair"];
				}
				return ["worn_handheld"];
			},
		}),
		"handheld_right_acc": genlayer_clothing_accessory('handheld', {
			srcfn(options) {
				const pattern = options.worn.handheld.pattern && !["tertiary", "primary"].includes(options.worn.handheld.setup.pattern_layer) ? "-" + options.worn.handheld.pattern?.replace(/ /g,"-") : '';

				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/right-${options.arm_right}${pattern}-acc.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_right === "none" || (options.prop && options.prop?.armPosition !== "handsfree")) return false;

				if (options.arm_right === "cover") return options.worn.handheld.setup.accessory === 1 && options.worn.handheld.setup.coverImage !== 0;
				return options.worn.handheld.setup.accessory === 1;
			},
			zfn(options) {
				const setup = options.worn.handheld.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				if (options.arm_right === "cover") return ZIndices.arms_cover;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
		}),
		"handheld_right_detail": genlayer_clothing_detail('handheld', {
			srcfn(options) {
				const pattern = options.worn.handheld.pattern ? "-" + options.worn.handheld.pattern?.replace(/ /g,"-") : "";
				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/right-${options.arm_right}${pattern}.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_right === "none" || (options.prop && options.prop?.armPosition !== "handsfree")) return false;

				const hasRightDetail = options.worn.handheld.setup.pattern_layer === "tertiary" && !!options.worn.handheld.pattern;

				if (options.arm_right === "cover") return hasRightDetail && options.worn.handheld.setup.coverImage !== 0;
				return hasRightDetail;
			},
			zfn(options) {
				const setup = options.worn.handheld.setup;
				if (options.arm_right === "cover" && V.worn.handheld.holdPosition === "right_cover" && setup.zIndex) return ZIndices[setup.zIndex];
				if (options.arm_right === "cover") return ZIndices.arms_cover;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
		}),
		"handheld_left": {
			srcfn(options) {
				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/left-${options.arm_left}.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_left === "none" || (options.prop && options.prop.armPosition !== "handsfree")) return false;

				if (options.arm_left === "cover") return options.worn.handheld.setup.leftImage === 1 && options.worn.handheld.setup.coverImage;
				return options.worn.handheld.setup.leftImage === 1;
			},
			zfn(options) {
				if (options.arm_left === "cover") return ZIndices.old_over_upper;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
			filtersfn() {
				return ["worn_handheld"];
			},
		},
		"handheld_left_acc": {
			srcfn(options) {
				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/left-${options.arm_left}-acc.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_left === "none" || (options.prop && options.prop.armPosition !== "handsfree")) return false;

				const hasLeftAcc = options.worn.handheld.setup.leftImage === 1 && options.worn.handheld.setup.accessory === 1

				if (options.arm_left === "cover") return hasLeftAcc && options.worn.handheld.setup.coverImage;
				return hasLeftAcc;
			},
			zfn(options) {
				if (options.arm_left === "cover") return ZIndices.old_over_upper;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
			filtersfn() {
				return ["worn_handheld_acc"];
			},
		},
		"handheld_left_detail": genlayer_clothing_detail('handheld', {
			srcfn(options) {
				const pattern = options.worn.handheld.pattern ? "-" + options.worn.handheld.pattern?.replace(/ /g,"-") : "";
				return `img/clothes/handheld/${options.worn.handheld.setup.variable}/left-${options.arm_left}${pattern}.png`;
			},
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || options.arm_left === "none" || (options.prop && options.prop.armPosition !== "handsfree"))
				return false;

				const hasLeftDetail = options.worn.handheld.setup.leftImage === 1 && !!options.worn.handheld.pattern && options.worn.handheld.setup.pattern_layer === "tertiary";

				if (options.arm_left === "cover") return hasLeftDetail && options.worn.handheld.setup.coverImage;
				return hasLeftDetail;
			},
			zfn(options) {
				if (options.arm_left === "cover") return ZIndices.old_over_upper;
				if (!options.worn.handheld.setup.zIndex) return ZIndices.handheld;
				return ZIndices[options.worn.handheld.setup.zIndex];
			},
		}),
		"handheld_back": genlayer_clothing_back_img('handheld', {
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || ["none", "cover"].includes(options.arm_right) || (options.prop && options.prop.armPosition !== "handsfree")) return false;

				return options.worn.handheld.setup.back_img === 1;
			},
			z: ZIndices.over_head_back
		}),
		"handheld_back_acc": genlayer_clothing_back_img_acc('handheld', {
			showfn(options) {
				if (options.worn.handheld.index <= 0 || !options.show_clothes || options.hide_all || ["none", "cover"].includes(options.arm_right) || (options.prop && options.prop.armPosition !== "handsfree")) return false;

				return options.worn.handheld.setup.back_img_acc === 1;
			},
			z: ZIndices.over_head_back
		}),
		/***
		 *    ██   ██ ███████  █████  ██████
		 *    ██   ██ ██      ██   ██ ██   ██
		 *    ███████ █████   ███████ ██   ██
		 *    ██   ██ ██      ██   ██ ██   ██
		 *    ██   ██ ███████ ██   ██ ██████
		 *
		 *
		 */
		"head": genlayer_clothing_main('head', {
			srcfn(options) {
				const dmg = options.worn.head.setup.accessory_integrity_img ? options.worn.upper.integrity : options.worn.head.integrity;
				const pattern = options.worn.head.pattern && !["tertiary", "secondary"].includes(options.worn.head.setup.pattern_layer) ? "-" + options.worn.head.pattern?.replace(/ /g,"-") : '';
				const isAltPosition = !options.alt_override && options.worn.head.setup.altposition !== undefined
					&& options.worn.head.alt === "alt"
					&& !options.worn.head.setup.altdisabled.includes("full");
				const end = isAltPosition ? '-alt' : '';

				return `img/clothes/head/${options.worn.head.setup.variable}/${dmg}${pattern}${end}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.head.index > 0
					&& options.worn.head.setup.mainImage !== 0
					&& !options.hide_all;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				if (options.worn.handheld.setup.mask_img === 1) {
					return `img/clothes/handheld/${options.worn.handheld.setup.variable}/mask.png`;
				};
			}
		}),
		"head_acc": genlayer_clothing_accessory('head', {
			srcfn(options) {
				const dmg = options.worn.head.setup.accessory_integrity_img ? `-${options.worn.upper.integrity}` : '';
				const pattern = options.worn.head.pattern && options.worn.head.setup.pattern_layer === "secondary" ? "-" + options.worn.head.pattern?.replace(/ /g,"-") : '';
				return `img/clothes/head/${options.worn.head.setup.variable}/acc${dmg}${pattern}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.head.index > 0
					&& options.worn.head.setup.accImage !== 0
					&& options.worn.head.setup.accessory === 1
					&& !options.hideHeadAcc
					&& !options.hide_all;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				if (options.worn.handheld.setup.mask_img === 1) {
					return `img/clothes/handheld/${options.worn.handheld.setup.variable}/mask.png`;
				};
			}
		}),
		"head_detail": genlayer_clothing_detail('head', {
			showfn(options) {
				return options.show_clothes
					&& options.worn.head.index > 0
					&& options.worn.head.setup.mainImage !== 0
					&& options.worn.head.setup.pattern_layer === "tertiary"
					&& !!options.worn.head.pattern
					&& !options.hide_all;
			},
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				if (options.worn.handheld.setup.mask_img === 1) {
					return `img/clothes/handheld/${options.worn.handheld.setup.variable}/mask.png`;
				};
			}
		}),
		"head_back_acc": genlayer_clothing_back_img_acc('head', {
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				if (options.worn.handheld.setup.mask_img === 1) {
					return `img/clothes/handheld/${options.worn.handheld.setup.variable}/mask.png`;
				}
				return options.headMask;
			}
		}),
		"head_back": genlayer_clothing_back_img('head', {
			masksrcfn(options) {
				if (options.worn.over_upper.setup.name === "kaiju costume")
					return `img/clothes/over-upper/kaiju/mask.png`;
				if (options.worn.handheld.setup.mask_img === 1) {
					return `img/clothes/handheld/${options.worn.handheld.setup.variable}/mask.png`;
				}
				return options.headMask;
			}
		}),
		/***
		 *     ██████  ██    ██ ███████ ██████          ██   ██ ███████  █████  ██████
		 *    ██    ██ ██    ██ ██      ██   ██         ██   ██ ██      ██   ██ ██   ██
		 *    ██    ██ ██    ██ █████   ██████          ███████ █████   ███████ ██   ██
		 *    ██    ██  ██  ██  ██      ██   ██         ██   ██ ██      ██   ██ ██   ██
		 *     ██████    ████   ███████ ██   ██ ███████ ██   ██ ███████ ██   ██ ██████
		 *
		 *
		 */
		"over_head": genlayer_clothing_main('over_head'),
		"over_head_acc": genlayer_clothing_accessory('over_head'),
		"over_head_back_acc": genlayer_clothing_back_img_acc('over_head'),
		"over_head_back": genlayer_clothing_back_img('over_head'),
		/***
		 *    ███████  █████   ██████ ███████
		 *    ██      ██   ██ ██      ██
		 *    █████   ███████ ██      █████
		 *    ██      ██   ██ ██      ██
		 *    ██      ██   ██  ██████ ███████
		 *
		 *
		 */

		"face": genlayer_clothing_main('face', {
			zfn(options) {
				const isAltPosition = !options.alt_override
					&& options.worn.face.setup.altposition !== undefined
					&& options.worn.face.alt === "alt";
				const check = isAltPosition
					&& (options.worn.face.setup.type.includes("cool")
						|| options.worn.face.setup.type.includes("glasses"));

				if (check) return ZIndices.over_head;
				return options.facewear_layer === "front" ? ZIndices.facewear - 12.5 : ZIndices.facewear;
			},
		}),
		"face_acc": genlayer_clothing_accessory('face', {
			zfn(options) {
				const isAltPosition = !options.alt_override
					&& options.worn.face.setup.altposition !== undefined
					&& options.worn.face.alt === "alt";
				const check = isAltPosition
					&& (options.worn.face.setup.type.includes("cool")
						|| options.worn.face.setup.type.includes("glasses"));

				if (check) return ZIndices.over_head;
				return options.facewear_layer === "front" ? ZIndices.facewear - 12.5 : ZIndices.facewear;
			},
		}),
		"face_back_acc": genlayer_clothing_back_img_acc('face'),
		"face_back": genlayer_clothing_back_img('face'),

		/***
		 *    ███    ██ ███████  ██████ ██   ██
		 *    ████   ██ ██      ██      ██  ██
		 *    ██ ██  ██ █████   ██      █████
		 *    ██  ██ ██ ██      ██      ██  ██
		 *    ██   ████ ███████  ██████ ██   ██
		 *
		 *
		 */
		"neck": genlayer_clothing_main('neck', {
			srcfn(options) {
				const isAltPosition = !options.alt_override
					&& options.worn.neck.setup.altposition !== undefined
					&& options.worn.neck.alt === "alt";

				let collar = "";
				if (options.worn.neck.setup.has_collar === 1 && options.worn.upper.setup.has_collar === 1 && !(options.worn.upper.setup.name === "dress shirt" && options.worn.upper.alt === "alt")) {
					collar = '-nocollar';
				} else if (options.worn.neck.setup.name === "sailor ribbon" && options.worn.upper.setup.name === "serafuku") {
					collar = "-serafuku";
				}
				const pattern = options.worn.neck.pattern && !["tertiary", "secondary"].includes(options.worn.neck.pattern_layer) ? "-" + options.worn.neck.pattern?.replace(/ /g,"-") : '';
				const alt = isAltPosition ? '-alt' : '';

				const setupVar = options.worn.neck.setup.variable;
				const integrity = options.worn.neck.integrity;
				return `img/clothes/neck/${setupVar}/${integrity}${collar}${pattern}${alt}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.neck.index > 0
					&& options.worn.neck.setup.mainImage !== 0
					&& !options.hide_all;
			},
			masksrcfn(options) {
				return options.high_waist_suspenders ? "img/clothes/neck/suspenders/mask.png" : null;
			},
			zfn(options) {
				const setup = options.worn.neck.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				return options.hood_mask ? ZIndices.collar : ZIndices.neck;
			},
		}),
		"neck_acc": genlayer_clothing_accessory('neck', {
			srcfn(options) {
				const isAltPosition = !options.alt_override
					&& options.worn.neck.setup.altposition !== undefined
					&& options.worn.neck.alt === "alt";
				const integrity = options.worn.neck.setup.accessory_integrity_img ? `-${options.worn.neck.integrity}` : '';
				const alt = isAltPosition ? '-alt' : '';
				const pattern = options.worn.neck?.pattern && options.worn.neck?.pattern_layer === "secondary" ? "-" + options.worn.neck.pattern?.replace(/ /g,"-") : '';

				const setupVar = options.worn.neck.setup.variable;
				return `img/clothes/neck/${setupVar}/acc${integrity}${pattern}${alt}.png`;
			},
			showfn(options) {
				return options.show_clothes
					&& options.worn.neck.index > 0
					&& options.worn.neck.setup.accImage !== 0
					&& options.worn.neck.setup.accessory === 1
					&& !options.hideLeash;
			},
			zfn(options) {
				const setup = options.worn.neck.setup;
				if (setup.zIndex) return ZIndices[setup.zIndex];
				const check = options.worn.head.setup.mask_img === 1
					&& !(options.hood_down
						&& options.worn.head.setup.hood
						&& options.worn.head.setup.outfitSecondary !== undefined);
				return check ? ZIndices.collar : ZIndices.neck;
			},
			dyfn(options) {
				return options.high_waist_suspenders ? -8 : 0;
			},
		}),
		/***
		 *    ██      ███████  ██████  ███████
		 *    ██      ██      ██       ██
		 *    ██      █████   ██   ███ ███████
		 *    ██      ██      ██    ██      ██
		 *    ███████ ███████  ██████  ███████
		 *
		 *
		 */
		"legs": genlayer_clothing_main('legs', {
			zfn(options) {
				const check = (options.worn.under_lower.setup.set === options.worn.under_upper.setup.set
					|| options.worn.under_lower.setup.high_img === 1) && options.worn.legs.setup.high_img !== 1;

				if (check) return ZIndices.legs;
				return ZIndices.legs_high;
			},
			masksrcfn(options) {
				return options.legsMask;
			},
		}),
		"legs_acc": genlayer_clothing_accessory('legs', {
			zfn(options) {
				const check = options.worn.under_lower.setup.set === options.worn.under_upper.setup.set
					|| options.worn.under_lower.setup.high_img === 1;

				if (check) return ZIndices.legs;
				return ZIndices.legs_high;
			},
			masksrcfn(options) {
				return options.legsMask;
			},
		}),
		"legs_detail": genlayer_clothing_detail('legs', {
			showfn(options) {
				return options.show_clothes
					&& options.worn.legs.index > 0
					&& options.worn.legs.setup.mainImage !== 0
					&& options.worn.legs.setup.pattern_layer === "tertiary"
					&& !!options.worn.legs.pattern
					&& !options.hide_all;
			},
		}),
		"legs_back_acc": genlayer_clothing_back_img_acc('legs'),
		"legs_back": genlayer_clothing_back_img('legs'),
		/***
		 *    ███████ ███████ ███████ ████████
		 *    ██      ██      ██         ██
		 *    █████   █████   █████      ██
		 *    ██      ██      ██         ██
		 *    ██      ███████ ███████    ██
		 *
		 *
		 */
		"feet": genlayer_clothing_main('feet', {
			zfn(options) {
				const check = options.lower_tucked
					&& !options.worn.lower.setup.notuck
					&& !options.worn.feet.setup.notuck;

				if (check) return ZIndices.lower_tucked_feet;
				return ZIndices.feet;
			},
		}),
		"feet_acc": genlayer_clothing_accessory('feet', {
			zfn(options) {
				const check = options.lower_tucked
					&& !options.worn.lower.setup.notuck
					&& !options.worn.feet.setup.notuck;

				if (check) return ZIndices.lower_tucked_feet;
				return ZIndices.feet;
			},
		}),
		"feet_details": genlayer_clothing_detail('feet'),
		"feet_back_acc": genlayer_clothing_back_img_acc('feet'),
		"feet_back": genlayer_clothing_back_img('feet'),
		/***
		 *    ███████  ██████  ██      ██       ██████  ██     ██ ███████ ██████
		 *    ██      ██    ██ ██      ██      ██    ██ ██     ██ ██      ██   ██
		 *    █████   ██    ██ ██      ██      ██    ██ ██  █  ██ █████   ██████
		 *    ██      ██    ██ ██      ██      ██    ██ ██ ███ ██ ██      ██   ██
		 *    ██       ██████  ███████ ███████  ██████   ███ ███  ███████ ██   ██
		 */
		"follower_base": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.base}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.base;
			},
			z: ZIndices.head,
		},
		"follower_left_arm": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.left_arm}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.left_arm;
			},
			z: ZIndices.head + 1,
		},
		"follower_clothes_left_arm": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.clothes_left_arm}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.clothes_left_arm;
			},
			z: ZIndices.head + 4,
		},
		"follower_hair": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.hair}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.hair;
			},
			z: ZIndices.head + 6,
		},
		"follower_under_clothes": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.under_clothes}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.under_clothes;
			},
			z: ZIndices.head + 3,
		},
		"follower_clothes": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.clothes}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.clothes;
			},
			z: ZIndices.head + 5,
		},
		"follower_writing_right_cheek": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_cheek}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_cheek;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_chest": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_chest}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_chest;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_left_arm": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_left_arm}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_left_arm;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_right_arm": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_arm}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_arm;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_left_shoulder": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_left_shoulder}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_left_shoulder;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_right_shoulder": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_shoulder}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_shoulder;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_left_thigh": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_left_thigh}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_left_thigh;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_right_thigh": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_thigh}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_thigh;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_left_leg": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_left_leg}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_left_leg;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_right_leg": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_leg}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_leg;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_left_foot": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_left_foot}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_left_foot;
			},
			z: ZIndices.head + 2,
		},
		"follower_writing_right_foot": {
			animation: "idle",
			srcfn(options) {
				return `img/clothes/props/npc/${options.follower.name}/${options.follower.writing_right_foot}.png`;
			},
			showfn(options) {
				return !!options.follower && !!options.follower.writing_right_foot;
			},
			z: ZIndices.head + 2,
		},
		/**
		 *     ██████  █████  ███    ██ ██    ██  █████  ███████
		 *    ██      ██   ██ ████   ██ ██    ██ ██   ██ ██
		 *    ██      ███████ ██ ██  ██ ██    ██ ███████ ███████
		 *    ██      ██   ██ ██  ██ ██  ██  ██  ██   ██      ██
		 *     ██████ ██   ██ ██   ████   ████   ██   ██ ███████
		 *
		 *    ███████ ███████ ███████ ███████  ██████ ████████ ███████
		 *    ██      ██      ██      ██      ██         ██    ██
		 *    █████   █████   █████   █████   ██         ██    ███████
		 *    ██      ██      ██      ██      ██         ██         ██
		 *    ███████ ██      ██      ███████  ██████    ██    ███████
		 */

		"precipitation_back": {
			animationfn() {
				return Weather.precipitation === "snow" ? "snowBack" : "rain";
			},
			srcfn() {
				const type = Weather.precipitation;
				const intensity = normaliseFileName(Weather.name);
				return `img/misc/ambient/precipitation/${type}/${intensity}-back.png`;
			},
			showfn(options) {
				return !T.hideSidebarEffects && !!options.precipitation;
			},
			z: ZIndices.background,
		},
		"precipitation_front": {
			animationfn() {
				return Weather.precipitation === "snow" ? "snowFront" : "rain";
			},
			srcfn() {
				const type = Weather.precipitation;
				const intensity = normaliseFileName(Weather.name);
				return `img/misc/ambient/precipitation/${type}/${intensity}-front.png`;
			},
			showfn(options) {
				return !T.hideSidebarEffects && !!options.precipitation;
			},
			z: ZIndices.foreground,
		},
		"cold_breath": {
			animationfn() {
				return (V.arousal >= 6000 || V.pain >= 40) ? "playerBreathFast" : "playerBreath";
			},
			src: `img/misc/ambient/player-breath.png`,
			showfn(options) {
				return !T.hideSidebarEffects && !!options.temperature;
			},
			z: ZIndices.foreground,
		},
		"water_breath": {
			animationfn() {
				return (V.arousal >= 6000 || V.pain >= 40) ? "waterBreathFast" : "waterBreath";
			},
			src: `img/misc/ambient/water/breath.png`,
			showfn(options) {
				return !T.hideSidebarEffects && !!options.water;
			},
			z: ZIndices.foreground,
		},
		"water_back": {
			animation: "waterBack",
			src: `img/misc/ambient/water/back.png`,
			showfn(options) {
				return !T.hideSidebarEffects && !!options.water;
			},
			z: ZIndices.background,
		},
		"water_front": {
			animation: "waterFront",
			src: `img/misc/ambient/water/front.png`,
			showfn(options) {
				return !T.hideSidebarEffects && !!options.water;
			},
			z: ZIndices.foreground,
		},
		"fire_back": {
			animationfn() {
				const intensity = V.farm_assault ? 2 : T.tempEffects?.fire || V.fire;
				return `fireBack${intensity}`;
			},
			srcfn() {
				const intensity = V.farm_assault ? 2 : T.tempEffects?.fire || V.fire;
				return `img/misc/ambient/fire/back-${intensity}.png`;
			},
			showfn(options) {
				return !T.hideSidebarEffects && !!options.fire;
			},
			z: ZIndices.background,
		},
		"fire_front": {
			animation: "fireFront",
			src: `img/misc/ambient/fire/front.png`,
			showfn(options) {
				return !T.hideSidebarEffects && (!!options.fire || !!options.fireFront);
			},
			z: ZIndices.foreground,
		},
		"petals_back": {
			animationfn() {
				const direction = T.tempEffects?.petals === "reverse" ? "Floating" : "Falling";
				return `petals${direction}`;
			},
			srcfn(options) {
				return `img/misc/ambient/petals/back-${options.petalColour}.png`;
			},
			showfn(options) {
				return !T.hideSidebarEffects && !!options.petals;
			},
			z: ZIndices.background,
		},
		"petals_front": {
			animationfn() {
				const direction = T.tempEffects?.petals === "reverse" ? "Floating" : "Falling";
				return `petals${direction}`;
			},
			srcfn(options) {
				return `img/misc/ambient/petals/front-${options.petalColour}.png`;
			},
			showfn(options) {
				return !T.hideSidebarEffects && !!options.petals;
			},
			z: ZIndices.foreground,
		},
		"vines": {
			animation: "idle",
			z: ZIndices.upper,
			showfn(options) {
				return !!options.vines;
			},
			src: `img/clothes/feet/vines/full-body.png`,
		},
		"prop": genlayer_prop(),
		"prop_acc": genlayer_prop_acc(),
		"prop_underarm": genlayer_prop({
			showfn(options) {
				return !!options.prop.show && !!options.prop.overUnderSplit;
			},
			srcfn(options) {
				return `img/clothes/props/${options.prop.folder}/${options.prop.name}-underarm.png`
			},
			zfn(options) {
				return options.zupperright - 1;
			},
		}),
		"prop_underarm_acc": genlayer_prop_acc({
			showfn(options) {
				return !!options.prop.show && !!options.prop.overUnderAccSplit;
			},
			srcfn(options) {
				return `img/clothes/props/${options.prop.folder}/${options.prop.name}-underarm-acc.png`
			},
			zfn(options) {
				return options.zupperright - 1;
			},
		}),
		"wraithFlash": {
			animation: "wraithFlash",
			showfn(options) {
				if (!options.wraithFlash || !Time.isBloodMoon() || V.combat) return false;
				// V.daily.wraithFlash is reused by the accent animation to make sure they always run together.
				if (V.daily.wraithFlash) return false;
				if (random(1, 70) === 1) {
					V.daily.wraithFlash = true;
					return true;
				}
				return false;
			},
			srcfn() {
				const hasBlueEyes = !["haunt", "despair"].includes(V.wraith.state);
				return hasBlueEyes ? "img/misc/ambient/wraith/wraith-flash-blue.png" : "img/misc/ambient/wraith/wraith-flash-red.png";
			},
			scale: false,
			width: 256,
			height: 256,
			dy: 0,
			z: ZIndices.background,
		},
		"wraithFlashAccent": {
			animation: "wraithFlashAccent",
			showfn(options) {
				if (!options.wraithFlash || !Time.isBloodMoon() || V.combat) return false;
				const hasBlueEyes = !["haunt", "despair"].includes(V.wraith.state);
				return !hasBlueEyes && V.daily.wraithFlash;
			},
			srcfn() {
				const hasBlueEyes = !["haunt", "despair"].includes(V.wraith.state);
				return hasBlueEyes ? "img/misc/ambient/wraith/wraith-flash-blue.png" : "img/misc/ambient/wraith/wraith-flash-red.png";
			},
			scale: false,
			width: 256,
			height: 256,
			dy: 0,
			z: ZIndices.background,
		},
		"wraithMirror": {
			animation: "wraithMirrorFade",
			showfn() {
				return !!T.wraithMirror;
			},
			srcfn() {
				const hasBlueEyes = !["haunt", "despair"].includes(V.wraith?.state);
				return hasBlueEyes ? "img/misc/ambient/wraith/wraith-flash-blue.png" : "img/misc/ambient/wraith/wraith-flash-red.png";
			},
			scale: false,
			width: 256,
			height: 256,
			dy: 0,
			z: ZIndices.background,
		},

		// new layer template
		/*
		"": {
			srcfn(options) {
				return ""
			},
			z: ZIndices.,
			animation: "idle"
		},
		*/
	}