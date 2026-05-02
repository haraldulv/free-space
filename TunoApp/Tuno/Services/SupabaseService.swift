import Foundation
import Supabase

/// Per-environment-konstanter. Staging-targetet kompileres med
/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING` (se project.yml).
/// Prod-targetet bygges uten flagget og bruker default-greinen nedenfor.
///
/// Når Supabase staging-branch er opprettet må `stagingSupabaseURL` og
/// `stagingSupabaseAnonKey` oppdateres med faktiske verdier (se
/// docs/staging.md).
enum AppConfig {
    #if STAGING
    static let supabaseURL = URL(string: "https://STAGING-REF.supabase.co")!
    static let supabaseAnonKey = "STAGING_ANON_KEY_PLACEHOLDER"
    static let siteURL = "https://staging.tuno.no"
    #else
    static let supabaseURL = URL(string: "https://mqyeptwrfrhwxtysccnp.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWVwdHdyZnJod3h0eXNjY25wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyODczOTMsImV4cCI6MjA4OTg2MzM5M30.m2wAmIbKR6Ptz2YL1IIaznLHBeGJi2MUgexQQb-t4dg"
    static let siteURL = "https://www.tuno.no"
    #endif

    /// Google Maps-nøkkelen er restrictet på Cloud Console-nivå (HTTP-referrer
    /// + iOS bundle), ikke per environment. Begge bundles (no.tuno.app og
    /// no.tuno.app.staging) må være whitelistet i Cloud Console.
    static let googleMapsAPIKey = "AIzaSyD4nwntMqBziqyUwi860y4EyAJJWCOTrRw"

    /// True når dette er staging-build. Brukes for å tegne en debug-banner
    /// eller endre tittel-tekst der det er nyttig.
    static var isStaging: Bool {
        #if STAGING
        return true
        #else
        return false
        #endif
    }
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
