#' Geographic query of biodiversity databases based on U.S. Fish and Wildlife
#'  Service (USFWS) property boundaries
#'
#' @section General overview:
#' The basic process is to query GBIF, BISON, iDigBio, the Berkeley
#'  'Ecoinformatics' Engine, and AntWeb based on the bounding box
#'  associated with each \code{fws} and any requested buffer.  For VertNet,
#'  the API requires spatial searches using a lat/lon coordinate and search
#'  radius.  We calculate the radius needed to fully capture the desired
#'  geometry.  Records are subsequently filtered based on the exact geometry.
#'  Additionally, we provide the options to:
#'  \itemize{
#'    \item scrub records to reduce the number of returned records for each
#'       \code{fws} (details below);
#'    \item attempt to link each observation with an Integrated Taxonomic Information
#'       System (ITIS) record. Note that if ITIS linking is attempted, and a match found,
#'       the scientific name will be converted to this 'accepted' name identified by ITIS.
#'  }
#'
#' @section Scrubbing details:
#' By default (\code{scrub = "strict"}), this function scrubs a lot of records.
#'  Specifically, it retains a single record for each species, giving preference to
#'  records with associated media (e.g., photo, audio) within a given property.  The
#'  retained record is typically the most recent with evidence to support the
#'  identification. Records for which evidence was not available (i.e., no associated
#'  collection or catalog number) are removed.  Moderate scrubbing
#'  (\code{scrub = "moderate"}) attempts only to duplicate records (i.e., identical
#'  catalog numbers) and redundant observations (i.e., multiple individuals of the same
#'  species recorded on the same date at a single location). All records can be
#'  returned with (\code{scrub = "none"}).
#'
#' @section Additional boundary information:
#' The boundaries specified by the \code{admin} option to the \code{bnd} argument
#'  delineates those lands and waters administered by the USFWS in North
#'  America, U.S. Trust Territories and Possessions. It may also include
#'  inholdings that are not administered by the USFWS. The primary source
#'  for this information is the USFWS Realty program. See
#'  \url{https://ecos.fws.gov/ServCat/Reference/Profile/60739} for more
#'  information.
#'
#' The boundaries specified by the \code{acq} option to the \code{bnd} argument
#'  delineates the external boundaries of lands and waters that are approved
#'  for acquisition by the USFWS in North America, U.S. Trust Territories and
#'  Possessions. The primary source for this information is the USFWS Realty
#'  program. See \url{https://ecos.fws.gov/ServCat/Reference/Profile/60738} for
#'  more information.
#'
#' @section Important usage limitations/notes:
#' This function exists strictly to extract occurrence data for a given
#'  \code{fws} property. Attempts at estimating or inferring relative abundance
#'  are most strongly discouraged and most likely meaningless.
#'
#' The extraction of records occurs on a property-by-property basis so the same
#'  record may occur in multiple polygons depending on buffer specifications.
#'
#' @param fws character string indicating USFWS properties, typically National
#'  Wildlife Refuges, within and around which the user wishes to extract species
#'  occurrence records.  This string *should* result from running
#'  \code{\link{find_fws}} to avoid potential mismatches.  See examples.
#' @param bnd character scalar indicating the type of property boundary to use.
#'  Default ("admin") uses the current administrative boundary.  The approved
#'  acquisition boundary ("acq") is another option.
#' @param scrub character; one of 'strict' (default), 'moderate', or 'none',
#'  indicating the extent to which to reduce the number of records returned for
#'  a given \code{fws}.  See details.
#' @param itis logical (default TRUE); attempt to link occurrence records to
#'  ITIS information?
#' @param buffer numeric scalar; distance (km) from the \code{fws} \code{bnd} to
#'  include in the search for species occurrence records. Default is no buffer.
#' @param verbose logical (default TRUE); print messages during species occurrence
#'  queries?
#' @param timeout integer; time, in seconds, to allow for HTTP requests to
#'  process. Default is 20 minutes (\code{timeout = 1200L}), which should permit most
#'  of the largest GBIF queries to complete on a ~ 20 Mbps internet connection. GBIF
#'  is nearly always the slowest request. If timeouts are a recurring problem, it may
#'  be worth increasing this parameter.
#' @export
#' @return Nothing. But generates a \code{rds} for each property in \code{export_dir}
#'  with the following columns if \code{itis = TRUE} (default).  If \code{itis = FALSE},
#'  only a subset of these columns is returned, and the scientific name (\code{sci_name})
#'  is that associated with the observation from the \code{bio_repo} source, **not** from
#'  ITIS:
#'  \describe{
#'    \item{class}{Taxonomic class of observation, from ITIS, if available.}
#'    \item{tsn}{Taxonomic serial number, from ITIS, if available.}
#'    \item{taxon_rank}{Taxonomic rank of observation, from ITIS, if available.}
#'    \item{sci_name}{Accepted scientific name, from ITIS, if available. Note, however,
#'          that if \code{taxon_rank} is available and is not 'Species', this scientific
#'          name is likely **not** accepted by ITIS.}
#'    \item{com_name}{Presumed most "accepted" vernacular name, from ITIS, if available.}
#'    \item{lon}{Longitude (WGS84) of observation.}
#'    \item{lat}{Latitude (WGS84) of observation.}
#'    \item{loc_unc_m}{Locational uncertainty (m) of observation coordinates; typically
#'          unavailable.}
#'    \item{year}{Year of observation, if available.}
#'    \item{month}{Month of observation, if available.}
#'    \item{day}{Day of month of observation, if available.}
#'    \item{evidence}{Attempt to link observation to a URL that best substantiates the
#'          observation, if available, generally in the following order: (1) URL to
#'          observation with media (photo, audio, video) or the media itself, (2) URL
#'          to the observation in the original collection, (3) URL of the collection,
#'          with catalog number, or (4) URL of the institution housing the collection,
#'          with catalog number.}
#'    \item{bio_repo}{Biodiversity database source of the observation, currently one of
#'          GBIF, BISON, iDigBio, VertNet, EcoEngine, or AntWeb.}
#'    \item{note}{Additional notes on the observation, currently restricted to indicating
#'          that a matching taxon was not found in ITIS.}
#'  }
#' @examples
#' \dontrun{
#' # Single refuge, administrative boundary, no buffer
#' # By default, records are scrubbed very strictly (see Details)
#'  # Mountain Longleaf National Wildlife Refuge
#' ml <- find_fws("longleaf")
#' fws_occ(fws = ml)
#'
#' # Multiple refuges, acquisition boundary with 5 km buffer, moderate scrubbing
#' multi <- find_fws(c("longleaf", "romain"))
#' fws_occ(fws = multi, bnd = "acq", scrub = "moderate", buffer = 5)
#'
#' # All Region 4 (southeast) refuges, with defaults
#' r4 <- find_fws(region = 4)
#' fw_spp(r4)
#' }

fws_occ <- function(fws = NULL, bnd = c("admin", "acq"),
                      scrub = c("strict", "moderate", "none"),
                      itis = TRUE, buffer = 0, verbose = TRUE,
                      timeout = 1200L) {

  if (is.null(fws)) stop("You must provide valid property names to query.",
                            "\nSee `?find_fws` for examples.")
  bnd <- match.arg(bnd)
  scrub <- match.arg(scrub)

  # Import spatial data for relevant properties
  check_cadastral()
  props <- prep_cadastral(fws, bnd, verbose)

  # Import global registery of biodiversity repositories
  grbio <- get_grbio()

  # Cycle through properties
  if (verbose)
    out <- lapply(fws, function(prop) {
        retrieve_occ(props, prop, buffer, scrub, itis, grbio, timeout)})
  else
    out <- pbapply::pblapply(fws, function(prop) {
      suppressMessages(
          retrieve_occ(props, prop, buffer, scrub, itis, grbio, timeout))})

  attributes(out) <- list(names = Cap(shorten_orgnames(fws)),
                          class = "fwspp",
                          boundary = bnd, scrubbing = scrub,
                          itis = itis, buffer_km = buffer,
                          timeout = timeout)

  if (!dir.exists(export_dir)) dir.create(export_dir)

  # FORMER CSV EXPORT CODE
  # MODIFY TO RDS
  # CHECK IF FILE EXISTS, IF SO SKIP? OR OVERWRITE?
    invisible(
      lapply(seq_along(out), function(i) {
        tmp_fn <- paste0(gsub(" |[.]", "", names(out)[i]), ".csv")
        if (inherits(out[[i]], "try-error")) {
          cat("fw_spp failed for", names(out)[i], "\n")
        } else if (is.null(out[[i]])) {
          cat("No valid observations found for", names(out)[i], "\n")
        } else {
          utils::write.csv(out[[i]], row.names = FALSE,
                           file = file.path(export_dir, tmp_fn))
        }
      })
    )

    return(out)

}