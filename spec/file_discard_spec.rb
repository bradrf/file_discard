#!/usr/bin/env ruby

begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  # not required, but nice for reports on what code the tests have touched
end

require 'tmpdir'
require 'minitest/spec'
require 'minitest/autorun'

load File.expand_path(File.join(File.dirname(__FILE__),'..','lib','file_discard.rb'))

describe FileDiscard do

  describe :Discarder do
    let(:base) { Pathname.new(Dir.mktmpdir(File.basename(__FILE__,'.rb') + '_')) }
    let(:home) do
      h = base.join('home')
      h.mkdir
      h
    end

    let(:home_trash) { '.Trash' }
    let(:trash) do
      t = home.join(home_trash)
      t.mkdir
      t
    end

    let(:discarder) { FileDiscard::OsxDiscarder.new(home) }

    before do
      FileDiscard.discarder = discarder
      FileDiscard.create_trash_when_missing = false
    end

    after do
      base.rmtree
    end

    it 'should not allow removal of special directories' do
      ['.','..'].each do |dir|
        ->{ FileDiscard.discard(dir) }.must_raise Errno::EINVAL
      end
    end

    describe 'when mixed in' do
      before do
        FileDiscard.mix_it_in!
      end

      it 'should extend classes' do
        [File, Pathname].each do |klass|
          klass.must_respond_to :discard
        end
      end

      it 'should fail without trash' do
        f = File.new(base.join('file.txt').to_s, 'w')
        ->{ f.discard }.must_raise FileDiscard::TrashMissing
      end

      it 'should support creating missing trash' do
        FileDiscard.create_trash_when_missing = true
        f = File.new(base.join('file.txt').to_s, 'w')
        f.discard
      end

      describe 'with trash in the home' do
        def sorted_trash
          trash.children(false).collect(&:to_s).sort
        end

        before do
          trash # ensure trash is created, but as late as possible for let-overrides
        end

        it 'should conditionally allow removal of empty directories' do
          d = base.join('foozy')
          d.mkdir
          ->{ FileDiscard.discard(d) }.must_raise Errno::EISDIR
          FileDiscard.discard(d, directory: true)
        end

        it 'should conditionally allow removal of non-empty directories' do
          d = base.join('foozy')
          d.mkdir
          f = d.join('stuff.txt')
          f.open('w') {|io| io.puts 'stuff'}
          ->{ FileDiscard.discard(d, directory: true) }.must_raise Errno::ENOTEMPTY
          FileDiscard.discard(d, recursive: true)
        end

        it 'should discard a file' do
          f = File.new(base.join('file.txt').to_s, 'w')
          f.discard
          sorted_trash.must_equal ['file.txt']
        end

        it 'should discard a pathname' do
          f = base.join('file.txt')
          f.open('w') {|io| io.puts 'nothing'}
          f.discard
          sorted_trash.must_equal ['file.txt']
        end

        describe 'with a symbolic links' do
          let(:target) do
            t = base.join('target')
            t.open('w') {|io| io.puts 'nothing'}
            t
          end

          let(:file) do
            f = home.join('pointer')
            f.make_symlink(target)
            f
          end

          it 'should leave the target untouched' do
            file.discard
            sorted_trash.must_equal ['pointer']
            target.exist?.must_equal true
          end

          it 'should not fail when target is missing' do
            target.unlink
            file.discard
            sorted_trash.must_equal ['pointer']
          end
        end

        describe 'with control over time' do
          before do
            # replace Time's strftime which FileDiscard relies on for uniquify
            class Time
              alias :orig_strftime :strftime
              @@strftime_count = 0
              def strftime(fmt)
                @@strftime_count += 1
                "9.8.#{@@strftime_count}"
              end
            end
          end

          after do
            if Time.now.respond_to? :orig_strftime
              class Time
                alias :strftime :orig_strftime
              end
            end
          end

          it 'should not overwite other trashed files' do
            f = trash.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}

            f = base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            FileDiscard.discard(f.to_s)
            sorted_trash.must_equal ['file 9.8.1.txt','file.txt']
          end

          it 'should use increasing precision for collisions' do
            3.times do |i|
              f = trash.join(%{file#{i == 0 ? '' : " 9.8.#{i}"}.txt})
              f.open('w') {|io| io.puts 'nothing'}
            end

            f = base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            File.discard(f.to_s)
            sorted_trash
              .must_equal ['file 9.8.1.txt', 'file 9.8.2.txt', 'file 9.8.3.txt', 'file.txt']
          end
        end

        describe 'with control over mountpoints' do
          class MyDiscarder < FileDiscard::Discarder
            private
            def mountpoint_of(pn)
              pn
            end
          end

          let(:home_trash) { base.join('mytrash-%s' % Process.uid) }
          let(:discarder)  { MyDiscarder.new(home, 'mytrash', 'mytrash-%s') }

          it 'should not use the home trash' do
            f = base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            f.discard
            sorted_trash.must_equal ['file.txt']
          end
        end
      end
    end
  end
end
