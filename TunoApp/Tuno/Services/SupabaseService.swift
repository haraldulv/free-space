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
    static let supabaseURL = URL(string: "https://qqtgmcxzyuquunsxoqog.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxdGdtY3h6eXVxdXVuc3hvcW9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3OTY4MzQsImV4cCI6MjA5MzM3MjgzNH0.3GiqYGGtVitINtRccUbEfE5wEd8wz70BdQUwwEvQ1gw"
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

    /// Slå Vipps Login-knappen av/på. Settes til true når Kim har levert
    /// Vipps-credentials og web-server har env-vars satt.
    static let vippsEnabled = false
    /// nin-scope krever egen Vipps-godkjenning og egen avtale. Eget flagg
    /// lar Login leve i prod mens nin-knappen i Bli utleier sover til
    /// scopen er klar. Skru på sammen med NEXT_PUBLIC_VIPPS_NIN_ENABLED.
    static let vippsNinEnabled = false

    // Turnstile-captcha styres fra app_settings.turnstile_enabled i databasen
    // (se AuthManager.isTurnstileRequired), ikke fra en kompilert konstant.
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
