// import { Recommendation } from "./types";

// class BaseMedia {
//   id: string;
//   title: string;
//   imageUrl: string;
//   trailerUrl: string | undefined;
//   plot: string;
//   genres: string[];
//   releaseYear: string;
//   rating: number;
//   ratingCount: number;
//   popularityScore: number | undefined;
//   contentRating: string;
//   actors: string[];
//   directors: string[];
//   runTime: string;
//   recommendations: Recommendation[];

//   constructor(data: BaseMedia) {
//     this.id = data.id;
//     this.title = data.title;
//     this.imageUrl = data.imageUrl;
//     this.trailerUrl = data.trailerUrl;
//     this.plot = data.plot;
//     this.genres = data.genres;
//     this.releaseYear = data.releaseYear;
//     this.rating = data.rating;
//     this.ratingCount = data.ratingCount;
//     this.popularityScore = data.popularityScore;
//     this.contentRating = data.contentRating;
//     this.actors = data.actors;
//     this.directors = data.directors;
//     this.runTime = data.runTime;
//     this.recommendations = data.recommendations;
//   }
// }

// export class Movie extends BaseMedia {
//     constructor(data: Movie) {
//         super(data);
//     }
// }

// export class TVSeries extends BaseMedia {
//   seasonCount: number;
//   episodeCount: number | undefined;
//   endYear: string | undefined;

//   constructor(data: TVSeries) {
//     super(data);
//     this.seasonCount = data.seasonCount;
//     this.episodeCount = data.episodeCount;
//     this.endYear = data.endYear;
//   }
// }


// export type Media = TVSeries | Movie;
