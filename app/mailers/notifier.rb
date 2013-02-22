class Notifier < ActionMailer::Base
  default from: Rails.application.config.default_from
  default to: Rails.application.config.default_to

  def build_failed(build)
    @build = build
    mail subject: "[CruiseControl] #{@build.project.name} build #{@build.short_sha} failed"
  end

  def build_fixed(build)
    @build = build
    mail subject: "[CruiseControl] #{@build.project.name} build fixed"
  end
end
