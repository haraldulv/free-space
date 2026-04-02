import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = URL(string: "https://mqyeptwrfrhwxtysccnp.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWVwdHdyZnJod3h0eXNjY25wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI5MDg2MTksImV4cCI6MjA1ODQ4NDYxOX0.FnVACovJsMGFLHLvAqCUXHp-4MRbFHR9ln3V36S3KJY"
    static let siteURL = "https://www.tuno.no"
    static let googleMapsAPIKey = "" // Set in Info.plist or here
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
