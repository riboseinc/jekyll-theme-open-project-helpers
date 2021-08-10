require "spec_helper"
require "ostruct"

require "jekyll"
require "jekyll-theme-open-project-helpers/spec_builders/spec_builder"

RSpec.describe Jekyll::OpenProjectHelpers::SpecBuilder do
  it "test missing images warning" do
    spec_info = OpenStruct.new(
      data: {
        navigation: {
          items: [
            {
              title: "1",
              path: "1/",
            },
            {
              title: "2",
              path: "2/",
            },
            {
              title: "3",
              path: "3/",
            },
          ],
        },
      }.stringify_all_keys,
    )
    source = File.join(File.dirname(__FILE__), "../../fixtures")

    builder = Jekyll::OpenProjectHelpers::SpecBuilder.new(nil, spec_info, Dir.tmpdir, source, "png_diagrams", {})

    allow(builder).to receive(:build_spec_page) { "fake_page" }

    expect do
      builder.build_spec_pages(nil, spec_info, source, Dir.tmpdir, {})
    end.to output(/SPECIFIED PNG NOT FOUND/).to_stderr
  end

  it "test unused images warning" do
    spec_info = OpenStruct.new(
      data: {
        navigation: {
          items: [
            {
              title: "1",
              path: "1/",
            },
          ],
        },
      }.stringify_all_keys,
    )
    source = File.join(File.dirname(__FILE__), "../../fixtures")

    builder = Jekyll::OpenProjectHelpers::SpecBuilder.new(nil, spec_info, Dir.tmpdir, source, "png_diagrams", {})

    allow(builder).to receive(:build_spec_page) { "fake_page" }

    expect do
      builder.build_spec_pages(nil, spec_info, source, Dir.tmpdir, {})
    end.to output(/UNUSED PNG/).to_stderr
  end
end
