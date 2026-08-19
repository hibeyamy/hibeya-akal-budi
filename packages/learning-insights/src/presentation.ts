import type {
  LearningSignal
} from "./types";


export interface SignalPresentation {
  labelMs: string;

  labelEn: string;

  descriptionMs: string;

  descriptionEn: string;
}


export const signalPresentation:
  Record<
    LearningSignal,
    SignalPresentation
  > = {

    exploring: {
      labelMs:
        "Sedang meneroka",

      labelEn:
        "Exploring",

      descriptionMs:
        "Baru mula bertemu dan meneroka pengalaman pembelajaran ini.",

      descriptionEn:
        "Beginning to encounter and explore this learning experience."
    },


    developing: {
      labelMs:
        "Sedang berkembang",

      labelEn:
        "Developing",

      descriptionMs:
        "Sudah mendapat beberapa peluang untuk mencuba dan masih membina kebiasaan.",

      descriptionEn:
        "Has had several opportunities to practise and is still building familiarity."
    },


    "growing-familiarity": {
      labelMs:
        "Semakin biasa",

      labelEn:
        "Growing familiarity",

      descriptionMs:
        "Menunjukkan kebiasaan yang semakin baik melalui beberapa pengalaman.",

      descriptionEn:
        "Showing increasing familiarity across several experiences."
    },


    "showing-confidence": {
      labelMs:
        "Semakin yakin",

      labelEn:
        "Showing confidence",

      descriptionMs:
        "Menunjukkan respons yang konsisten dalam beberapa pengalaman terkini.",

      descriptionEn:
        "Showing consistent responses across several recent experiences."
    }

  };
  