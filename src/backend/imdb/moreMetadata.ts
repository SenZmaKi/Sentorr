export type MoreMetadataJson = {
  props: {
    pageProps: {
      tconst: string
      aboveTheFoldData: {
        id: string
        productionStatus: {
          currentProductionStage: {
            id: string
            text: string
            __typename: string
          }
          productionStatusHistory: Array<{
            status: {
              id: string
              text: string
              __typename: string
            }
            __typename: string
          }>
          restriction: any
          __typename: string
        }
        runtime: {
          seconds: number
          displayableProperty: {
            value: {
              plainText: string
              __typename: string
            }
            __typename: string
          }
          __typename: string
        }
        plot: {
          plotText: {
            plainText: string
            __typename: string
          }
          language: {
            id: string
            __typename: string
          }
          __typename: string
        }
        releaseYear: {
          year: number
          endYear: number
          __typename: string
        }
        meterRanking: {
          currentRank: number
          rankChange: {
            changeDirection: string
            difference: number
            __typename: string
          }
          __typename: string
        }
        canHaveEpisodes: boolean
        series: any
        titleText: {
          text: string
          __typename: string
        }
        titleType: {
          displayableProperty: {
            value: {
              plainText: string
              __typename: string
            }
            __typename: string
          }
          text: string
          id: string
          isSeries: boolean
          isEpisode: boolean
          categories: Array<{
            value: string
            __typename: string
          }>
          canHaveEpisodes: boolean
          __typename: string
        }
        originalTitleText: {
          text: string
          __typename: string
        }
        certificate: {
          rating: string
          __typename: string
        }
        releaseDate: {
          day: number
          month: number
          year: number
          __typename: string
        }
        canRate: {
          isRatable: boolean
          __typename: string
        }
        ratingsSummary: {
          aggregateRating: number
          voteCount: number
          __typename: string
        }
        primaryImage: {
          id: string
          width: number
          height: number
          url: string
          caption: {
            plainText: string
            __typename: string
          }
          __typename: string
        }
        images: {
          total: number
          edges: Array<{
            node: {
              id: string
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        videos: {
          total: number
          __typename: string
        }
        primaryVideos: {
          edges: Array<{
            node: {
              id: string
              createdDate: string
              isMature: boolean
              runtime: {
                value: number
                __typename: string
              }
              name: {
                value: string
                language: string
                __typename: string
              }
              description: {
                value: string
                language: string
                __typename: string
              }
              timedTextTracks: Array<any>
              recommendedTimedTextTrack: any
              thumbnail: {
                url: string
                height: number
                width: number
                __typename: string
              }
              primaryTitle: {
                id: string
                titleText: {
                  text: string
                  __typename: string
                }
                originalTitleText: {
                  text: string
                  __typename: string
                }
                releaseYear: {
                  year: number
                  __typename: string
                }
                __typename: string
              }
              playbackURLs: Array<{
                displayName: {
                  value: string
                  language: string
                  __typename: string
                }
                videoMimeType: string
                videoDefinition: string
                url: string
                __typename: string
              }>
              contentType: {
                id: string
                displayName: {
                  value: string
                  __typename: string
                }
                __typename: string
              }
              previewURLs: Array<{
                displayName: {
                  value: string
                  language: string
                  __typename: string
                }
                videoMimeType: string
                videoDefinition: string
                url: string
                __typename: string
              }>
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        externalLinks: {
          total: number
          __typename: string
        }
        metacritic: any
        keywords: {
          total: number
          edges: Array<{
            node: {
              text: string
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        genres: {
          genres: Array<{
            text: string
            id: string
            __typename: string
          }>
          __typename: string
        }
        plotContributionLink: {
          url: string
          __typename: string
        }
        credits: {
          total: number
          __typename: string
        }
        principalCredits: Array<{
          totalCredits: number
          category: {
            text: string
            id: string
            __typename: string
          }
          credits: Array<{
            name: {
              nameText: {
                text: string
                __typename: string
              }
              id: string
              __typename: string
            }
            attributes: any
            __typename: string
          }>
          __typename: string
        }>
        reviews: {
          total: number
          __typename: string
        }
        criticReviewsTotal: {
          total: number
          __typename: string
        }
        triviaTotal: {
          total: number
          __typename: string
        }
        engagementStatistics: {
          watchlistStatistics: {
            displayableCount: {
              text: string
              __typename: string
            }
            __typename: string
          }
          __typename: string
        }
        subNavCredits: {
          total: number
          __typename: string
        }
        subNavReviews: {
          total: number
          __typename: string
        }
        subNavTrivia: {
          total: number
          __typename: string
        }
        subNavFaqs: {
          total: number
          __typename: string
        }
        subNavTopQuestions: {
          total: number
          __typename: string
        }
        titleGenres: {
          genres: Array<{
            genre: {
              text: string
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        meta: {
          canonicalId: string
          publicationStatus: string
          __typename: string
        }
        castPageTitle: {
          edges: Array<{
            node: {
              name: {
                nameText: {
                  text: string
                  __typename: string
                }
                __typename: string
              }
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        creatorsPageTitle: Array<{
          credits: Array<{
            name: {
              nameText: {
                text: string
                __typename: string
              }
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }>
        directorsPageTitle: Array<any>
        countriesOfOrigin: {
          countries: Array<{
            id: string
            __typename: string
          }>
          __typename: string
        }
        production: {
          edges: Array<{
            node: {
              company: {
                id: string
                companyText: {
                  text: string
                  __typename: string
                }
                __typename: string
              }
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        featuredReviews: {
          edges: Array<{
            node: {
              author: {
                nickName: string
                __typename: string
              }
              summary: {
                originalText: string
                __typename: string
              }
              text: {
                originalText: {
                  plainText: string
                  __typename: string
                }
                __typename: string
              }
              authorRating: number
              submissionDate: string
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        __typename: string
      }
      mainColumnData: {
        id: string
       cast: {
          edges: Array<{
            node: {
              name: {
                id: string
                nameText: {
                  text: string
                  __typename: string
                }
                primaryImage: {
                  url: string
                  width: number
                  height: number
                  __typename: string
                }
                __typename: string
              }
              attributes: any
              category: {
                id: string
                __typename: string
              }
              characters: Array<{
                name: string
                __typename: string
              }>
              episodeCredits: {
                total: number
                yearRange: {
                  year: number
                  endYear: number
                  __typename: string
                }
                __typename: string
              }
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
        episodes: {
          episodes: {
            total: number
            __typename: string
          }
          seasons: Array<{
            number: number
            __typename: string
          }>
          years: Array<{
            year: number
            __typename: string
          }>
          totalEpisodes: {
            total: number
            __typename: string
          }
          unknownSeasonEpisodes: {
            total: number
            __typename: string
          }
          topRated: {
            edges: Array<{
              node: {
                ratingsSummary: {
                  aggregateRating: number
                  __typename: string
                }
                __typename: string
              }
              __typename: string
            }>
            __typename: string
          }
          __typename: string
        }
        moreLikeThisTitles: {
          edges: Array<{
            node: {
              id: string
              titleText: {
                text: string
                __typename: string
              }
              titleType: {
                id: string
                text: string
                canHaveEpisodes: boolean
                displayableProperty: {
                  value: {
                    plainText: string
                    __typename: string
                  }
                  __typename: string
                }
                __typename: string
              }
              originalTitleText: {
                text: string
                __typename: string
              }
              primaryImage: {
                id: string
                width: number
                height: number
                url: string
                caption: {
                  plainText: string
                  __typename: string
                }
                __typename: string
              }
              releaseYear: {
                year: number
                endYear?: number
                __typename: string
              }
              ratingsSummary: {
                aggregateRating: number
                voteCount: number
                __typename: string
              }
              runtime: {
                seconds: number
                __typename: string
              }
              certificate?: {
                rating: string
                __typename: string
              }
              canRate: {
                isRatable: boolean
                __typename: string
              }
              titleGenres: {
                genres: Array<{
                  genre: {
                    text: string
                    __typename: string
                  }
                  __typename: string
                }>
                __typename: string
              }
              canHaveEpisodes: boolean
              __typename: string
            }
            __typename: string
          }>
          __typename: string
        }
      }
    }
  }
}