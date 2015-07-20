def git_repo(url, name, opts)
  if File.writable?(name)
    git_repo = Git.open(name)
  else
    uri = Addressable::URI.parse("#{url}.git")
    uri.user = opts[:gitusername]
    uri.password = opts[:gitpassword]
    git_repo = Git.clone(uri, name)
  end
  git_repo.reset_hard
  git_repo
end

def clean_branch(repo, branch)
  return if branch == 'master'
  repo.branch(branch).delete
  repo.chdir do
    `git push origin :#{branch} 1>/dev/null`
  end
end

def prepare_branch(repo, source, destination, clean = false)
  repo.fetch
  repo.branch(source).checkout
  repo.pull
  repo.branch(destination)
  clean_branch(repo, destination) if clean
  repo.branch(destination).checkout
  repo.merge(source,
             "CI: merge source branch #{source} to release #{destination}")
end
