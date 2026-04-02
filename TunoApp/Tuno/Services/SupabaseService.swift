import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = URL(string: "https://mqyeptwrfrhwxtysccnp.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWVwdHdyZnJod3h0eXNjY25wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyODczOTMsImV4cCI6MjA4OTg2MzM5M30.m2wAmIbKR6Ptz2YL1IIaznLHBeGJi2MUgexQQb-t4dg"
    static let siteURL = "https://www.tuno.no"
    static let googleMapsAPIKey = "AIzaSyD4nwntMqBziqyUwi860y4EyAJJWCOTrRw"
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
