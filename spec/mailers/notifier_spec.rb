require 'spec_helper'

describe Notifier do
  let(:changeset1) { 'first_changeset' }
  let(:changeset2) { 'second_changeset' }

  let(:project) { FactoryGirl.create(:project) }
  let(:build) { project.register_build(ref: 'master', after: changeset1) }

  let(:other_build_same_changeset) { project.register_build(ref: 'master', after: changeset1) }
  let(:other_build_new_changeset) { project.register_build(ref: 'master', after: changeset2) }

  let(:mail) do
    mail = double('Mail')
    mail.stub(:deliver)
    mail
  end

  def run_build(build)
    build.run
    build.update_attribute :trace, Faker::Lorem.paragraph
  end

  it "should send email notification when the initial build fails" do
    run_build(build)
    Notifier.should_receive(:build_failed).once.with(build) { mail }
    build.drop
  end

  it "should send email notification when the initial build succeeds" do
    run_build(build)
    Notifier.should_receive(:build_fixed).once.with(build) { mail }
    build.success
  end

  it "should send email notification when the build fails" do
    build.update_attribute(:status, [:pending, :success, :failed, :cancelled].sample)

    second_build = other_build_same_changeset
    run_build(second_build)
    Notifier.should_receive(:build_failed).once.with(second_build) { mail }
    second_build.drop
  end

  it "should send email notification when the build fails in a new changeset" do
    build.update_attribute(:status, [:pending, :success, :failed, :cancelled].sample)

    second_build = other_build_new_changeset
    run_build(second_build)
    Notifier.should_receive(:build_failed).once.with(second_build) { mail }
    second_build.drop
  end

  it "should send email notification when the build changes to fixed" do
    run_build(build)
    build.drop

    second_build = other_build_same_changeset
    run_build(second_build)

    Notifier.should_receive(:build_fixed).once.with(second_build) { mail }

    second_build.success
  end

  it "should not send email notification when the build continues to be fixed in a new changeset" do
    run_build(build)
    build.success

    second_build = other_build_new_changeset
    run_build(second_build)

    Notifier.should_not_receive(:build_fixed)

    second_build.success
  end

  it "should not send email notification when the build continues to be fixed within the same changeset" do
    run_build(build)
    build.success

    second_build = other_build_same_changeset
    run_build(second_build)

    Notifier.should_not_receive(:build_fixed)

    second_build.success
  end

  context "email contents" do
    specify "#build_fixed" do
      run_build(build)
      build.success

      @email = Notifier.build_fixed(build)
      @email.should have_subject("[CruiseControl] #{build.project.name} build fixed")
      @email.body.should match(build.short_sha)
      @email.body.should_not match(build.trace)
    end

    specify "#build_failed" do
      run_build(build)
      build.drop

      @email = Notifier.build_failed(build)
      @email.should have_subject("[CruiseControl] #{build.project.name} build #{build.short_sha} failed")
      @email.body.should have_link(project_build_url(build.project, build))
      @email.body.should match(build.trace)
    end
  end
end
